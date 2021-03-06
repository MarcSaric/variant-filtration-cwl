#!/usr/bin/env cwl-runner

class: CommandLineTool

cwlVersion: v1.0
doc: |
    Creates a tar.gz archive of a list of files 

requirements:
  - class: DockerRequirement
    dockerPull: quay.io/ncigdc/gdc-biasfilter-tool:3839a594cab6b8576e76124061cf222fb3719f20
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing: $(inputs.input_files) 

inputs:
  input_files:
    type:
      type: array
      items: File
      inputBinding:
        valueFrom: $(self.basename)
    doc: files you want to archive 
    inputBinding:
      position: 1

  output_archive_name:
    type: string
    inputBinding:
      prefix: -hczf
      position: 0

outputs:
  output_archive:
    type: File
    outputBinding:
      glob: $(inputs.output_archive_name)
    doc: The archived directory

baseCommand: [tar]
