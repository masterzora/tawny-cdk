require_relative 'scale'

module CDK
  class USCALE < CDK::SCALE
    # The original UScale handled unsigned values.
    # Since Ruby's typing is different this is really just SCALE
    # but is nice it's nice to have this for compatibility/completeness
    # sake.

    def object_type
      :USCALE
    end
  end
end
