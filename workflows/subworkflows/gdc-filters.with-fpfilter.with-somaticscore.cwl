#!/usr/bin/env cwl-runner

cwlVersion: v1.0

class: Workflow

requirements:
  - class: InlineJavascriptRequirement
  - class: StepInputExpressionRequirement
  - class: MultipleInputFeatureRequirement
  - class: SubworkflowFeatureRequirement
  - $import: ../../tools/schemas.cwl

inputs:
  input_vcf:
    type: File
    doc: The VCF file you want to filter
  tumor_bam:
    type: File
    doc: The tumor BAM file
  tumor_bam_index:
    type: File
    doc: The tumor BAI file
  file_prefix: 
    type: string
  full_ref_fasta:
    doc: Full reference fasta containing all scaffolds
    type: File
  full_ref_fasta_index:
    doc: Full reference fasta index
    type: File
  full_ref_dictionary:
    doc: Full reference fasta sequence dictionary
    type: File
  main_ref_fasta:
    doc: Main chromosomes only fasta
    type: File
  main_ref_fasta_index:
    doc: Main chromosomes only fasta index
    type: File
  main_ref_dictionary:
    doc: Main chromosomes only fasta sequence dictionary
    type: File
  vcf_metadata:
    doc: VCF metadata record
    type: "../../tools/schemas.cwl#vcf_metadata_record"
  drop_somatic_score:
    doc: If the somatic score is less than this value, remove it from VCF
    type: int?
    default: 25 
  min_somatic_score:
    doc: If the somatic score is less than this value, add filter tag 
    type: int?
    default: 40 
  oxoq_score:
    doc: oxoq score from picard
    type: float

outputs:
  fpfilter_time:
    type: "../../tools/schemas.cwl#time_record"
    outputSource: fpfilterWorkflow/fpfilter_time
 
  dkfz_time:
    type: "../../tools/schemas.cwl#time_record"
    outputSource: dkfzWorkflow/dkfz_time_record

  dkfz_qc_archive:
    type: File
    outputSource: dkfzWorkflow/dkfz_qc_archive

  dtoxog_archive:
    type: File
    outputSource: dtoxogWorkflow/dtoxog_archive

  final_vcf:
    type: File
    outputSource: formatFinalWorkflow/processed_vcf

steps:
  firstUpdate:
    run: ../../tools/PicardUpdateSequenceDictionary.cwl
    in:
      input_vcf: input_vcf
      sequence_dictionary: full_ref_dictionary
      output_filename:
        source: file_prefix 
        valueFrom: "$(self + '.first.dict.vcf')"
    out: [ output_file ]

  firstFormatVcf:
    run: ../../tools/PicardVcfFormatConverter.cwl
    in:
      input_vcf: firstUpdate/output_file 
      output_filename:
        source: file_prefix 
        valueFrom: "$(self + '.first.fmt.vcf.gz')"
    out: [ output_file ]

  somaticScoreWorkflow:
    run: ./utils/SomaticScoreFilterWorkflow.cwl
    in:
      input_vcf: firstFormatVcf/output_file 
      drop_somatic_score: drop_somatic_score
      min_somatic_score: min_somatic_score
      uuid: file_prefix 
    out: [ somaticscore_vcf ]

  fpfilterWorkflow:
    run: ./utils/FpFilterWorkflow.cwl
    in:
      input_vcf: somaticScoreWorkflow/somaticscore_vcf
      input_bam: tumor_bam
      input_bam_index: tumor_bam_index
      uuid: file_prefix 
      reference_sequence: full_ref_fasta
      reference_sequence_index: full_ref_fasta_index
    out: [ fpfilter_vcf, fpfilter_time ]

  formatVcfWorkflow:
    run: ./utils/FormatInputVcfWorkflow.cwl
    in:
      input_vcf: fpfilterWorkflow/fpfilter_vcf 
      uuid: file_prefix 
      sequence_dictionary: full_ref_dictionary 
    out: [ snv_vcf, indel_vcf ]

  dkfzWorkflow:
    run: ./utils/DkfzFilterWorkflow.cwl
    in:
      input_snp_vcf: formatVcfWorkflow/snv_vcf
      bam: tumor_bam
      bam_index: tumor_bam_index
      reference_sequence: full_ref_fasta
      reference_sequence_index: full_ref_fasta_index
      uuid: file_prefix 
    out: [ dkfz_vcf, dkfz_qc_archive, dkfz_time_record ]

  dtoxogWorkflow:
    run: ./utils/DToxoGWorkflow.cwl
    in:
      input_snp_vcf: dkfzWorkflow/dkfz_vcf
      oxoq_score: oxoq_score
      bam: tumor_bam
      bam_index: tumor_bam_index
      full_reference_sequence: full_ref_fasta
      full_reference_sequence_index: full_ref_fasta_index
      full_reference_sequence_dictionary: full_ref_dictionary
      main_reference_sequence: main_ref_fasta
      main_reference_sequence_index: main_ref_fasta_index
      main_reference_sequence_dictionary: main_ref_dictionary
      uuid: file_prefix 
    out: [ dtoxog_archive, dtoxog_vcf ] 

  formatFinalWorkflow:
    run: ./utils/MergeAndFormatFinalVcfs.cwl
    in:
      input_snp_vcf: dtoxogWorkflow/dtoxog_vcf
      input_indel_vcf: formatVcfWorkflow/indel_vcf
      full_reference_sequence_dictionary: full_ref_dictionary
      main_reference_sequence_dictionary: main_ref_dictionary
      vcf_metadata: vcf_metadata
      uuid: file_prefix 
    out: [ processed_vcf ]
