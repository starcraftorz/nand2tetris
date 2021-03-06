require 'securerandom'
module VM
  module Instruction
    class Gt
      attr_reader :id

      def initialize(line, context)
        @id = SecureRandom.hex(4)
      end

      def commented_assemblies
        ['// gt'] + to_assemblies
      end

      def to_assemblies
        %W(
          @SP
          D=M-1
          M=D
          A=M
          D=M
          @R14
          M=D

          @SP
          D=M-1
          M=D
          A=M
          D=M
          @R13
          M=D

          @R13
          D=M
          @R14
          D=D-M
          @#{id}.GREATER_THAN
          D;JGT

          D=0
          @#{id}.PUSH_RESULT
          1;JMP

          (#{id}.GREATER_THAN)
          D=-1

          (#{id}.PUSH_RESULT)
          @SP
          A=M
          M=D
          D=A+1
          @SP
          M=D)
      end
    end
  end
end
