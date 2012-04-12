# Enables exporting and importing ActiveRecord associations of ActiveRecord
# models that include PortableModel.
#
module ActiveRecord::Associations

  class NotPortableError < StandardError

    def initialize(assoc)
      super("#{assoc.proxy_reflection.name}:#{assoc.proxy_reflection.klass.name} is not portable")
    end

    class << self

      def raise_on_not_portable(assoc)
        raise NotPortableError.new(assoc) unless assoc.proxy_reflection.klass.include?(PortableModel)
      end

    end

  end

  class AssociationProxy

    # Export the association to a YAML file.
    #
    def export_to_yml(filename)
      NotPortableError.raise_on_not_portable(self)

      Pathname.new(filename).open('w') do |out|
        YAML::dump(export_portable_association, out)
      end
    end

    # Import the association from a YAML file.
    #
    def import_from_yml(filename)
      NotPortableError.raise_on_not_portable(self)
      import_portable_association(YAML::load_file(filename))
    end

  protected

    # Used to make sure that imported records are associated with the
    # association owner.
    #
    def primary_key_hash
      { proxy_reflection.primary_key_name.to_s => proxy_owner.id }
    end

  end

  class HasOneAssociation

    # Export the association to a hash.
    #
    def export_portable_association
      NotPortableError.raise_on_not_portable(self)
      export_to_hash
    end

    # Import the association from a hash.
    #
    def import_portable_association(record_hash)
      NotPortableError.raise_on_not_portable(self)
      raise ArgumentError.new('specified argument is not a hash') unless record_hash.is_a?(Hash)

      proxy_owner.transaction do
        if target.nil?
          assoc_record = proxy_reflection.klass.import_from_hash(record_hash.merge(primary_key_hash))
          replace(assoc_record)
        else
          raise 'cannot replace existing association record'
        end
      end
    end

  end

  class HasManyAssociation

    # Export the association to an array of hashes.
    #
    def export_portable_association
      NotPortableError.raise_on_not_portable(self)
      map(&:export_to_hash)
    end

    # Import the association from an array of hashes.
    #
    def import_portable_association(record_hashes)
      NotPortableError.raise_on_not_portable(self)
      raise ArgumentError.new('specified argument is not an array of hashes') unless record_hashes.is_a?(Array) && record_hashes.all? { |record_hash| record_hash.is_a?(Hash) }

      proxy_owner.transaction do
        assoc_records = record_hashes.map { |record_hash| proxy_reflection.klass.import_from_hash(record_hash.merge(primary_key_hash)) }
        concat(*assoc_records)
      end
    end

  end

end