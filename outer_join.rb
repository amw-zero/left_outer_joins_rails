module OuterJoin
  extend ActiveSupport::Concern

  class_methods do

    # Shim until Rails 5
    # Supports joining with the following associations:
    #   has_many, has_many through:, belongs_to
    def left_outer_joins(association)
      association_info =  reflect_on_association(association)

      raise "#{self} has no association named #{association}" unless association_info

      join = case association_info
              when ActiveRecord::Reflection::ThroughReflection
                has_many_through_join(association, association_info)
              when ActiveRecord::Reflection::HasManyReflection
                has_many_join(association, association_info)
              when ActiveRecord::Reflection::BelongsToReflection
                belongs_to_join(association, association_info)
              end
      joins(join.join_sources)
    end

    def belongs_to_join(association, association_info)
      source_table = arel_table
      dest_table = reflect_on_association(association).class_name.constantize.arel_table
      foreign_key = reflect_on_association(association).foreign_key

      source_table
        .join(dest_table, Arel::Nodes::OuterJoin)
        .on(dest_table[:id].eq(source_table[foreign_key]))
    end

    def has_many_through_join(association, association_info)
      join_table_params, has_many_params = has_many_through_arel_info(association, association_info)

      source_table = has_many_params[:source_table]
      dest_table = has_many_params[:dest_table]
      foreign_key = has_many_params[:foreign_key]

      arel_outer_join(join_table_params)
        .join(source_table, Arel::Nodes::OuterJoin)
        .on(source_table[:id].eq(dest_table[foreign_key]))
    end

    def has_many_join(association, association_info)
      arel_outer_join(has_many_arel_info(association, association_info))
    end

    def arel_outer_join(source_table:, dest_table:, foreign_key:)
      source_table
        .join(dest_table, Arel::Nodes::OuterJoin)
        .on(source_table[:id].eq(dest_table[foreign_key]))
    end

    def has_many_through_arel_info(association, association_info)
      join_arel_table = arel_table
      join_dest_table = association_info.through_reflection.class_name.constantize.arel_table
      join_foreign_key = association_info.through_reflection.foreign_key

      source_arel_table = association_info.source_reflection.class_name.constantize.arel_table
      dest_arel_table = association_info.through_reflection.class_name.constantize.arel_table
      foreign_key = association_info.source_reflection.foreign_key.to_sym

      [
        {source_table: join_arel_table, dest_table: join_dest_table, foreign_key: join_foreign_key},
        {source_table: source_arel_table, dest_table: dest_arel_table, foreign_key: foreign_key}
      ]
    end

    def has_many_arel_info(association, association_info)
      source_arel_table = arel_table
      dest_constant = association_info.source_reflection.class_name.constantize
      dest_arel_table = dest_constant.arel_table

      source_table_sym = self.to_s.underscore
      foreign_key = dest_constant.reflect_on_association(source_table_sym).foreign_key

      {source_table: source_arel_table, dest_table: dest_arel_table, foreign_key: foreign_key}
    end

  end
end

# Add to initializer
ActiveRecord::Base.include(OuterJoin)
