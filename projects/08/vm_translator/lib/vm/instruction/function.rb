module VM
  module Instruction
    class Function
      attr_reader :name, :arity, :context

      def initialize(line, context)
        @context = context
        _, @name, arity = line.split
        @arity = arity.to_i
      end

      def commented_assemblies
        ["// function #{name} #{arity}"] + to_assemblies
      end

      def to_assemblies
        label_assemblies + initialize_local_variables_assemblies
      end

      private

      def label_assemblies
        %W(
          (#{name})
        )
      end

      def initialize_local_variables_assemblies
        1.upto(arity).map do |idx|
          PushConstant.new("0", context).to_assemblies
        end.flatten
      end
    end
  end
end
