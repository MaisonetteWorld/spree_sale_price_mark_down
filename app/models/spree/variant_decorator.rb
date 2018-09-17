module Spree
  Variant.class_eval do
    def mark_down
      @mark_down ||= find_mark_down
    end

    def taxon_ids_for_mark_down
      @taxon_ids ||= Spree::Taxon.joins(:classifications).where(spree_products_taxons: { product_id: product_id }).pluck(:id)
    end

    def taxon_ids_for_mark_down_skip
      taxon_ids_for_mark_down
    end

    def find_mark_down(reload = false)
      return nil if (@no_mark_down && !reload) || taxon_ids_for_mark_down.blank?

      md = Spree::MarkDown.connection.select_one(
      "SELECT
        spree_mark_downs.id
      FROM
        spree_mark_downs
        INNER JOIN spree_mark_downs_taxons ON spree_mark_downs_taxons.mark_down_id = spree_mark_downs.id
        INNER JOIN spree_taxons ON spree_taxons.id = spree_mark_downs_taxons.taxon_id
        LEFT JOIN spree_mark_downs_skip_taxons ON spree_mark_downs_skip_taxons.mark_down_id = spree_mark_downs.id AND spree_mark_downs_skip_taxons.skip_taxon_id IN (#{taxon_ids_for_mark_down_skip.join(',')})
        LEFT JOIN spree_taxons skip_taxons_spree_mark_downs ON skip_taxons_spree_mark_downs.id = spree_mark_downs_skip_taxons.skip_taxon_id
      WHERE
        spree_mark_downs_taxons.taxon_id IN (#{taxon_ids_for_mark_down.join(',')})
        AND spree_mark_downs_skip_taxons.mark_down_id IS NULL
        AND spree_mark_downs.active = true
        AND (start_at IS NULL OR start_at < '#{Time.zone.now}')
        AND (stop_at IS NULL OR stop_at > '#{Time.zone.now}')
      ORDER BY spree_mark_downs.created_at ASC"
      )

      @no_mark_down = md.blank?

      Spree::MarkDown.find_by(id: md['id']) if md.present?
    end

    def mark_down_sale_price_exists?
      !mark_down_sale_price.nil?
    end

    def mark_down_sale_price
      mark_down.calculate_sale_price(self) unless mark_down.blank?
    end
  end
end
