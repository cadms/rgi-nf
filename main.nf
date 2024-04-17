#!/usr/bin/env nextflow
params.input = "$baseDir/in"
params.output = "$baseDir/out"
params.gene_result_column = 16
params.gzip = false
params.type = "contig"
params.loose = false
params.nudge = false
params.low_quality = false

args = []
if (params.type) args.push("-t $params.type")
if (params.loose) args.push("--include_loose")
if (params.nudge) args.push("--include_nudge")
if (params.low_quality) args.push("--low_quality")

process RGI_MAIN{
    publishDir params.output, mode: 'copy'

    input:
    path fasta

    output:
    path "*.tsv"

    script:
    def prefix = fasta.getSimpleName()
    def is_compressed = fasta.getName().endsWith(".gz") ? true : false
    def fasta_name = fasta.getName().replace(".gz", "")

    """
    if [ "$is_compressed" == "true" ]; then
        gzip -c -d $fasta > $fasta_name
    fi

    rgi main -i $fasta \
        -o ${fasta_name}.out ${args.join(' ')} > ${fasta_name}.log 2>&1
    mv '$fasta_name'.out.txt '$fasta_name'.tsv
    """
}

process CSV{
    publishDir params.output, mode: 'copy'

    input:
    val tables

    output:
    path 'rgi_results.csv'

    exec:
    gene_list = []
    results = [:]
    tables.each { table ->
        sample_genes = []
        sample = file(table)
        allLines = sample.readLines()
        allLines.remove(0)//strip table header
        for( line : allLines ) {
            result = line.split()[params.gene_result_column]
            sample_genes.push(result)
        }
        sample_genes.unique()
        gene_list += sample_genes
        sample_name = sample.name.split("\\.").first()
        results[sample_name] = sample_genes
    }
    result_table = ""
    gene_list.unique().sort()
    results = results.sort()
    results.each{ sample_name, genes ->
        result_row = []
        gene_list.each { gene ->
            if (genes.contains(gene)){
                result_row += 1
            } else{
                result_row += 0
            }
        }
        result_row.push(sample_name)
        result_table += result_row.join(',') + "\n"
    }
    gene_list.sort()
    gene_list.push('Isolate')
    headers = gene_list.join(',') + "\n"
    result_table = headers + result_table

    csv_file = task.workDir.resolve('rgi_results.csv')
    csv_file.text = result_table
}

process ZIP{
    publishDir params.output, mode: 'copy'

    input:
    path files
    path csv

    output:
    path '*.tar.gz'

    """
    current_date=\$(date +"%Y-%m-%d")
    outfile="rgi_\${current_date}.tar.gz"
    tar -chzf \${outfile} ${files.join(' ')} $csv
    """
}

workflow {
    reads_ch = Channel
        .fromPath("$params.input/*{fas,gz,fasta,fsa,fsa.gz,fas.gz}")
    RGI_MAIN(reads_ch)
    CSV(RGI_MAIN.out.collect())

    if (params.gzip){
        ZIP(RGI_MAIN.out.collect(),CSV.out)
    }

}
