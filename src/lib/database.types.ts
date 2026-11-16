export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.18"
  }
  public: {
    Tables: {
      addresses: {
        Row: {
          area: string
          building: string | null
          city: string
          created_at: string
          id: string
          is_default: boolean
          label: string
          latitude: number | null
          longitude: number | null
          notes: string | null
          phone: string
          recipient_name: string
          street: string
          user_id: string
        }
        Insert: {
          area: string
          building?: string | null
          city: string
          created_at?: string
          id?: string
          is_default?: boolean
          label?: string
          latitude?: number | null
          longitude?: number | null
          notes?: string | null
          phone: string
          recipient_name: string
          street: string
          user_id: string
        }
        Update: {
          area?: string
          building?: string | null
          city?: string
          created_at?: string
          id?: string
          is_default?: boolean
          label?: string
          latitude?: number | null
          longitude?: number | null
          notes?: string | null
          phone?: string
          recipient_name?: string
          street?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "addresses_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      categories: {
        Row: {
          created_at: string
          id: string
          image_url: string | null
          is_active: boolean
          name_ar: string
          name_en: string | null
          parent_id: string | null
          slug: string
          sort_order: number
        }
        Insert: {
          created_at?: string
          id?: string
          image_url?: string | null
          is_active?: boolean
          name_ar: string
          name_en?: string | null
          parent_id?: string | null
          slug: string
          sort_order?: number
        }
        Update: {
          created_at?: string
          id?: string
          image_url?: string | null
          is_active?: boolean
          name_ar?: string
          name_en?: string | null
          parent_id?: string | null
          slug?: string
          sort_order?: number
        }
        Relationships: [
          {
            foreignKeyName: "categories_parent_id_fkey"
            columns: ["parent_id"]
            isOneToOne: false
            referencedRelation: "categories"
            referencedColumns: ["id"]
          },
        ]
      }
      favorites: {
        Row: {
          created_at: string
          product_id: string
          user_id: string
        }
        Insert: {
          created_at?: string
          product_id: string
          user_id: string
        }
        Update: {
          created_at?: string
          product_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "favorites_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "favorites_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      merchant_applications: {
        Row: {
          admin_note: string | null
          business_description: string | null
          city: string
          contact_phone: string
          created_at: string
          id: string
          proposed_store_name: string
          reviewed_at: string | null
          reviewed_by: string | null
          status: string
          user_id: string
        }
        Insert: {
          admin_note?: string | null
          business_description?: string | null
          city: string
          contact_phone: string
          created_at?: string
          id?: string
          proposed_store_name: string
          reviewed_at?: string | null
          reviewed_by?: string | null
          status?: string
          user_id: string
        }
        Update: {
          admin_note?: string | null
          business_description?: string | null
          city?: string
          contact_phone?: string
          created_at?: string
          id?: string
          proposed_store_name?: string
          reviewed_at?: string | null
          reviewed_by?: string | null
          status?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "merchant_applications_reviewed_by_fkey"
            columns: ["reviewed_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "merchant_applications_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      notifications: {
        Row: {
          body: string
          created_at: string
          data: Json
          id: string
          kind: string
          read_at: string | null
          title: string
          user_id: string
        }
        Insert: {
          body: string
          created_at?: string
          data?: Json
          id?: string
          kind?: string
          read_at?: string | null
          title: string
          user_id: string
        }
        Update: {
          body?: string
          created_at?: string
          data?: Json
          id?: string
          kind?: string
          read_at?: string | null
          title?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "notifications_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      order_events: {
        Row: {
          actor_id: string | null
          created_at: string
          description: string | null
          event_type: string
          id: string
          metadata: Json
          order_id: string
        }
        Insert: {
          actor_id?: string | null
          created_at?: string
          description?: string | null
          event_type: string
          id?: string
          metadata?: Json
          order_id: string
        }
        Update: {
          actor_id?: string | null
          created_at?: string
          description?: string | null
          event_type?: string
          id?: string
          metadata?: Json
          order_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "order_events_actor_id_fkey"
            columns: ["actor_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "order_events_order_id_fkey"
            columns: ["order_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["id"]
          },
        ]
      }
      order_items: {
        Row: {
          id: string
          line_total_jod: number
          merchant_status: string
          order_id: string
          product_id: string | null
          product_image_url: string | null
          product_name: string
          quantity: number
          store_id: string
          unit_price_jod: number
          variant_label: string | null
        }
        Insert: {
          id?: string
          line_total_jod: number
          merchant_status?: string
          order_id: string
          product_id?: string | null
          product_image_url?: string | null
          product_name: string
          quantity: number
          store_id: string
          unit_price_jod: number
          variant_label?: string | null
        }
        Update: {
          id?: string
          line_total_jod?: number
          merchant_status?: string
          order_id?: string
          product_id?: string | null
          product_image_url?: string | null
          product_name?: string
          quantity?: number
          store_id?: string
          unit_price_jod?: number
          variant_label?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "order_items_order_id_fkey"
            columns: ["order_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "order_items_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "order_items_store_id_fkey"
            columns: ["store_id"]
            isOneToOne: false
            referencedRelation: "stores"
            referencedColumns: ["id"]
          },
        ]
      }
      orders: {
        Row: {
          address_id: string | null
          buyer_id: string
          buyer_note: string | null
          created_at: string
          delivered_at: string | null
          delivery_fee_jod: number
          delivery_otp_hash: string | null
          discount_jod: number
          id: string
          order_number: string
          payment_method: Database["public"]["Enums"]["payment_method"]
          placed_at: string
          status: Database["public"]["Enums"]["order_status"]
          subtotal_jod: number
          total_jod: number
        }
        Insert: {
          address_id?: string | null
          buyer_id: string
          buyer_note?: string | null
          created_at?: string
          delivered_at?: string | null
          delivery_fee_jod?: number
          delivery_otp_hash?: string | null
          discount_jod?: number
          id?: string
          order_number?: string
          payment_method?: Database["public"]["Enums"]["payment_method"]
          placed_at?: string
          status?: Database["public"]["Enums"]["order_status"]
          subtotal_jod?: number
          total_jod?: number
        }
        Update: {
          address_id?: string | null
          buyer_id?: string
          buyer_note?: string | null
          created_at?: string
          delivered_at?: string | null
          delivery_fee_jod?: number
          delivery_otp_hash?: string | null
          discount_jod?: number
          id?: string
          order_number?: string
          payment_method?: Database["public"]["Enums"]["payment_method"]
          placed_at?: string
          status?: Database["public"]["Enums"]["order_status"]
          subtotal_jod?: number
          total_jod?: number
        }
        Relationships: [
          {
            foreignKeyName: "orders_address_id_fkey"
            columns: ["address_id"]
            isOneToOne: false
            referencedRelation: "addresses"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "orders_buyer_id_fkey"
            columns: ["buyer_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      platform_settings: {
        Row: {
          key: string
          updated_at: string
          value: Json
        }
        Insert: {
          key: string
          updated_at?: string
          value: Json
        }
        Update: {
          key?: string
          updated_at?: string
          value?: Json
        }
        Relationships: []
      }
      product_images: {
        Row: {
          alt_text: string | null
          id: string
          image_url: string
          product_id: string
          sort_order: number
        }
        Insert: {
          alt_text?: string | null
          id?: string
          image_url: string
          product_id: string
          sort_order?: number
        }
        Update: {
          alt_text?: string | null
          id?: string
          image_url?: string
          product_id?: string
          sort_order?: number
        }
        Relationships: [
          {
            foreignKeyName: "product_images_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
        ]
      }
      product_variants: {
        Row: {
          id: string
          option_name: string
          option_value: string
          product_id: string
          sku: string | null
          stock_quantity: number
        }
        Insert: {
          id?: string
          option_name: string
          option_value: string
          product_id: string
          sku?: string | null
          stock_quantity?: number
        }
        Update: {
          id?: string
          option_name?: string
          option_value?: string
          product_id?: string
          sku?: string | null
          stock_quantity?: number
        }
        Relationships: [
          {
            foreignKeyName: "product_variants_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
        ]
      }
      products: {
        Row: {
          category_id: string | null
          compare_at_price_jod: number | null
          created_at: string
          description: string | null
          id: string
          is_featured: boolean
          name: string
          price_jod: number
          sku: string | null
          slug: string
          status: Database["public"]["Enums"]["product_status"]
          stock_quantity: number
          store_id: string
          updated_at: string
        }
        Insert: {
          category_id?: string | null
          compare_at_price_jod?: number | null
          created_at?: string
          description?: string | null
          id?: string
          is_featured?: boolean
          name: string
          price_jod: number
          sku?: string | null
          slug: string
          status?: Database["public"]["Enums"]["product_status"]
          stock_quantity?: number
          store_id: string
          updated_at?: string
        }
        Update: {
          category_id?: string | null
          compare_at_price_jod?: number | null
          created_at?: string
          description?: string | null
          id?: string
          is_featured?: boolean
          name?: string
          price_jod?: number
          sku?: string | null
          slug?: string
          status?: Database["public"]["Enums"]["product_status"]
          stock_quantity?: number
          store_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "products_category_id_fkey"
            columns: ["category_id"]
            isOneToOne: false
            referencedRelation: "categories"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "products_store_id_fkey"
            columns: ["store_id"]
            isOneToOne: false
            referencedRelation: "stores"
            referencedColumns: ["id"]
          },
        ]
      }
      profiles: {
        Row: {
          avatar_url: string | null
          city: string | null
          country: string
          created_at: string
          full_name: string
          id: string
          is_blocked: boolean
          phone: string | null
          role: Database["public"]["Enums"]["app_role"]
          updated_at: string
        }
        Insert: {
          avatar_url?: string | null
          city?: string | null
          country?: string
          created_at?: string
          full_name?: string
          id: string
          is_blocked?: boolean
          phone?: string | null
          role?: Database["public"]["Enums"]["app_role"]
          updated_at?: string
        }
        Update: {
          avatar_url?: string | null
          city?: string | null
          country?: string
          created_at?: string
          full_name?: string
          id?: string
          is_blocked?: boolean
          phone?: string | null
          role?: Database["public"]["Enums"]["app_role"]
          updated_at?: string
        }
        Relationships: []
      }
      returns: {
        Row: {
          buyer_id: string
          details: string | null
          evidence_urls: string[]
          id: string
          order_id: string
          order_item_id: string | null
          reason: string
          requested_at: string
          resolved_at: string | null
          status: Database["public"]["Enums"]["return_status"]
        }
        Insert: {
          buyer_id: string
          details?: string | null
          evidence_urls?: string[]
          id?: string
          order_id: string
          order_item_id?: string | null
          reason: string
          requested_at?: string
          resolved_at?: string | null
          status?: Database["public"]["Enums"]["return_status"]
        }
        Update: {
          buyer_id?: string
          details?: string | null
          evidence_urls?: string[]
          id?: string
          order_id?: string
          order_item_id?: string | null
          reason?: string
          requested_at?: string
          resolved_at?: string | null
          status?: Database["public"]["Enums"]["return_status"]
        }
        Relationships: [
          {
            foreignKeyName: "returns_buyer_id_fkey"
            columns: ["buyer_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "returns_order_id_fkey"
            columns: ["order_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "returns_order_item_id_fkey"
            columns: ["order_item_id"]
            isOneToOne: false
            referencedRelation: "order_items"
            referencedColumns: ["id"]
          },
        ]
      }
      settlements: {
        Row: {
          adjustments_jod: number
          commission_jod: number
          created_at: string
          gross_jod: number
          id: string
          net_jod: number
          paid_at: string | null
          period_end: string
          period_start: string
          status: string
          store_id: string
        }
        Insert: {
          adjustments_jod?: number
          commission_jod?: number
          created_at?: string
          gross_jod?: number
          id?: string
          net_jod?: number
          paid_at?: string | null
          period_end: string
          period_start: string
          status?: string
          store_id: string
        }
        Update: {
          adjustments_jod?: number
          commission_jod?: number
          created_at?: string
          gross_jod?: number
          id?: string
          net_jod?: number
          paid_at?: string | null
          period_end?: string
          period_start?: string
          status?: string
          store_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "settlements_store_id_fkey"
            columns: ["store_id"]
            isOneToOne: false
            referencedRelation: "stores"
            referencedColumns: ["id"]
          },
        ]
      }
      shipments: {
        Row: {
          courier_id: string | null
          created_at: string
          delivered_at: string | null
          delivery_proof_url: string | null
          hub_received_at: string | null
          id: string
          order_id: string
          picked_up_at: string | null
          status: string
        }
        Insert: {
          courier_id?: string | null
          created_at?: string
          delivered_at?: string | null
          delivery_proof_url?: string | null
          hub_received_at?: string | null
          id?: string
          order_id: string
          picked_up_at?: string | null
          status?: string
        }
        Update: {
          courier_id?: string | null
          created_at?: string
          delivered_at?: string | null
          delivery_proof_url?: string | null
          hub_received_at?: string | null
          id?: string
          order_id?: string
          picked_up_at?: string | null
          status?: string
        }
        Relationships: [
          {
            foreignKeyName: "shipments_courier_id_fkey"
            columns: ["courier_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shipments_order_id_fkey"
            columns: ["order_id"]
            isOneToOne: true
            referencedRelation: "orders"
            referencedColumns: ["id"]
          },
        ]
      }
      stores: {
        Row: {
          address: string | null
          city: string | null
          commission_percent: number
          contact_phone: string | null
          created_at: string
          description: string | null
          id: string
          latitude: number | null
          logo_url: string | null
          longitude: number | null
          name: string
          owner_id: string
          slug: string
          status: string
          updated_at: string
        }
        Insert: {
          address?: string | null
          city?: string | null
          commission_percent?: number
          contact_phone?: string | null
          created_at?: string
          description?: string | null
          id?: string
          latitude?: number | null
          logo_url?: string | null
          longitude?: number | null
          name: string
          owner_id: string
          slug: string
          status?: string
          updated_at?: string
        }
        Update: {
          address?: string | null
          city?: string | null
          commission_percent?: number
          contact_phone?: string | null
          created_at?: string
          description?: string | null
          id?: string
          latitude?: number | null
          logo_url?: string | null
          longitude?: number | null
          name?: string
          owner_id?: string
          slug?: string
          status?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "stores_owner_id_fkey"
            columns: ["owner_id"]
            isOneToOne: true
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      approve_merchant_application: {
        Args: { p_application_id: string; p_store_slug: string }
        Returns: string
      }
      courier_update_shipment: {
        Args: {
          p_new_status: string
          p_proof_url?: string
          p_shipment_id: string
        }
        Returns: boolean
      }
      create_weekly_store_settlement: {
        Args: {
          p_period_end: string
          p_period_start: string
          p_store_id: string
        }
        Returns: string
      }
      get_my_deliveries: {
        Args: never
        Returns: {
          area: string
          building: string
          city: string
          delivery_notes: string
          latitude: number
          longitude: number
          order_id: string
          order_number: string
          order_status: Database["public"]["Enums"]["order_status"]
          recipient_name: string
          recipient_phone: string
          shipment_id: string
          shipment_status: string
          street: string
          total_jod: number
        }[]
      }
      place_order: {
        Args: { p_address_id: string; p_buyer_note?: string; p_items: Json }
        Returns: {
          delivery_fee_jod: number
          order_id: string
          order_number: string
          subtotal_jod: number
          total_jod: number
        }[]
      }
    }
    Enums: {
      app_role: "buyer" | "merchant" | "courier" | "admin"
      order_status:
        | "placed"
        | "confirmed"
        | "at_hub"
        | "out_for_delivery"
        | "delivered"
        | "cancelled"
        | "return_requested"
        | "returned"
      payment_method: "cash_on_delivery"
      product_status: "draft" | "active" | "hidden" | "out_of_stock"
      return_status:
        | "requested"
        | "approved"
        | "rejected"
        | "picked_up"
        | "received"
        | "refunded_cash"
        | "closed"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {
      app_role: ["buyer", "merchant", "courier", "admin"],
      order_status: [
        "placed",
        "confirmed",
        "at_hub",
        "out_for_delivery",
        "delivered",
        "cancelled",
        "return_requested",
        "returned",
      ],
      payment_method: ["cash_on_delivery"],
      product_status: ["draft", "active", "hidden", "out_of_stock"],
      return_status: [
        "requested",
        "approved",
        "rejected",
        "picked_up",
        "received",
        "refunded_cash",
        "closed",
      ],
    },
  },
} as const
