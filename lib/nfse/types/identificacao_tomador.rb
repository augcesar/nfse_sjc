module NFSe
  module Types
    class IdentificacaoTomador < Base
      def process
        build_into_self 'CpfCnpj', of: CpfCnpj
        build_field 'InscricaoMunicipal', :optional
      end
    end
  end
end
