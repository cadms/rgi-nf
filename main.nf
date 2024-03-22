#!/usr/bin/env nextflow
params.input = "$baseDir/in"
params.output = "$baseDir/out"
params.gene_result_column = 16
params.gzip = false

process RGI_MAIN{
    publishDir params.output, mode: 'copy'

    input:
    path sequence_file

    output:
    path "${sequence_file}.tsv"

    """
    rgi main -i $sequence_file \
        -o ${sequence_file}.out --input_type contig --clean > ${sequence_file}.log 2>&1
    mv '$sequence_file'.out.txt '$sequence_file'.tsv
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
