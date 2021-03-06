#!/usr/bin/env cwl-runner

cwlVersion: v1.0

class: Workflow

requirements:
  - class: InlineJavascriptRequirement
  - class: StepInputExpressionRequirement
  - class: MultipleInputFeatureRequirement
  - $import: ../../../tools/schemas.cwl

inputs:
  input_snp_vcf: File
  bam: File
  bam_index: File
  full_reference_sequence: File
  full_reference_sequence_index: File
  full_reference_sequence_dictionary: File
  main_reference_sequence: File
  main_reference_sequence_index: File
  main_reference_sequence_dictionary: File
  uuid: string
  oxoq_score: float

outputs:
  dtoxog_archive:
    type: File
    outputSource: archive_dtoxog/output_archive
  dtoxog_vcf:
    type: File
    outputSource: add_dtoxog_to_vcf/output_file

steps:
  intervals: 
    run: ../../../tools/CreateOxoGIntervals.cwl
    in:
      input_vcf: input_snp_vcf
      output_filename:
        source: uuid
        valueFrom: $(self + '.oxog.interval_list')
    out: [ output_interval_file ] 

  get_oxog:
    run: ../../../tools/BroadOxoG.cwl
    in:
      input_bam: bam
      input_bam_index: bam_index
      reference_sequence: full_reference_sequence
      reference_sequence_index: full_reference_sequence_index 
      reference_sequence_dictionary: full_reference_sequence_dictionary 
      intervals: intervals/output_interval_file
      output_filename:
        source: uuid
        valueFrom: $(self + '.oxog.metrics.txt')
    out: [ output_metrics_file ]

  make_dtoxog_input:
    run: ../../../tools/MakeMafForDToxoG.cwl
    in:
      reference_sequence: full_reference_sequence 
      reference_sequence_index: full_reference_sequence_index 
      gatk_oxog_file: get_oxog/output_metrics_file
      oxoq_score: oxoq_score
      input_vcf: input_snp_vcf 
      output_filename:
        source: uuid
        valueFrom: $(self + '.dtoxog.input.maf')
    out: [ output_maf_file ]

  dtoxog:
    run: ../../../tools/dToxoG.cwl
    in:
      input_maf: make_dtoxog_input/output_maf_file
      output_name: uuid
    out: [ output_dir, log_file ]

  archive_dtoxog:
    run: ../../../tools/ArchiveDirectory.cwl
    in:
      input_directory: dtoxog/output_dir
    out: [ output_archive ]

  process_dtoxog:
    run: ../../../tools/ProcessDToxoG.cwl
    in:
      input_maf:
        source: [ dtoxog/output_dir, uuid ]
        valueFrom: |
          ${
             var bp = self[0].location;
             var bname = self[1] + '.oxog.maf.all.maf.annotated';
             return({"location": bp+'/'+bname, "basename": bname, "class": "File"});
           }
      reference_fasta: full_reference_sequence
      reference_index: full_reference_sequence_index
      output_filename:
        source: uuid
        valueFrom: $(self + '.dtoxo.vcf.gz')
    out: [ output_file ]

  add_dtoxog_to_vcf:
    run: ../../../tools/AddOxoGFiltersToVcf.cwl
    in:
      input_vcf: input_snp_vcf
      input_dtoxog: process_dtoxog/output_file
      output_filename:
        source: uuid
        valueFrom: $(self + '.anno.vcf.gz')
    out: [ output_file ]
