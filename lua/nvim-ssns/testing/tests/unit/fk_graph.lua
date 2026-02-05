-- Test file: fk_graph.lua
-- IDs: 3901-4000
-- Tests: FKGraph utility module for FK chain building
--
-- Test categories:
-- - 3901-3930: Direct FK detection (1-hop)
-- - 3931-3960: Multi-hop FK chains
-- - 3961-3980: Label and detail building
-- - 3981-4000: Flatten and sort

return {
  -- Direct FK Detection (3901-3930)
  {
    id = 3901,
    type = "fk_graph",
    name = "Single FK from source table",
    input = {
      source_tables = { { name = "Employees", schema = "dbo" } },
      fk_relationships = {
        { from_table = "Employees", from_schema = "dbo", from_column = "DepartmentID", to_table = "Departments", to_schema = "dbo", to_column = "DepartmentID" },
      },
      max_depth = 2,
    },
    expected = {
      hop_count_1 = { "Departments" },
      hop_count_2 = {},
    },
  },
  {
    id = 3902,
    type = "fk_graph",
    name = "Multiple FKs from source table",
    input = {
      source_tables = { { name = "Employees", schema = "dbo" } },
      fk_relationships = {
        { from_table = "Employees", from_schema = "dbo", from_column = "DepartmentID", to_table = "Departments", to_schema = "dbo", to_column = "DepartmentID" },
        { from_table = "Employees", from_schema = "dbo", from_column = "ManagerID", to_table = "Managers", to_schema = "dbo", to_column = "ManagerID" },
        { from_table = "Employees", from_schema = "dbo", from_column = "LocationID", to_table = "Locations", to_schema = "dbo", to_column = "LocationID" },
      },
      max_depth = 2,
    },
    expected = {
      hop_count_1 = { "Departments", "Managers", "Locations" },
      hop_count_2 = {},
    },
  },
  {
    id = 3903,
    type = "fk_graph",
    name = "FK with schema prefix",
    input = {
      source_tables = { { name = "Orders", schema = "sales" } },
      fk_relationships = {
        { from_table = "Orders", from_schema = "sales", from_column = "CustomerID", to_table = "Customers", to_schema = "sales", to_column = "CustomerID" },
      },
      max_depth = 2,
    },
    expected = {
      hop_count_1 = { "Customers" },
      hop_count_2 = {},
    },
  },
  {
    id = 3904,
    type = "fk_graph",
    name = "Self-referential FK excluded",
    input = {
      source_tables = { { name = "Employees", schema = "dbo" } },
      fk_relationships = {
        { from_table = "Employees", from_schema = "dbo", from_column = "ManagerID", to_table = "Employees", to_schema = "dbo", to_column = "EmployeeID" },
      },
      max_depth = 2,
    },
    expected = {
      hop_count_1 = {},
      hop_count_2 = {},
    },
  },
  {
    id = 3905,
    type = "fk_graph",
    name = "FK from multiple source tables",
    input = {
      source_tables = {
        { name = "Orders", schema = "dbo" },
        { name = "OrderDetails", schema = "dbo" },
      },
      fk_relationships = {
        { from_table = "Orders", from_schema = "dbo", from_column = "CustomerID", to_table = "Customers", to_schema = "dbo", to_column = "CustomerID" },
        { from_table = "OrderDetails", from_schema = "dbo", from_column = "ProductID", to_table = "Products", to_schema = "dbo", to_column = "ProductID" },
      },
      max_depth = 2,
    },
    expected = {
      hop_count_1 = { "Customers", "Products" },
      hop_count_2 = {},
    },
  },
  {
    id = 3906,
    type = "fk_graph",
    name = "No FK relationships",
    input = {
      source_tables = { { name = "Employees", schema = "dbo" } },
      fk_relationships = {},
      max_depth = 2,
    },
    expected = {
      hop_count_1 = {},
      hop_count_2 = {},
    },
  },
  {
    id = 3907,
    type = "fk_graph",
    name = "FK to same table excluded",
    input = {
      source_tables = { { name = "Categories", schema = "dbo" } },
      fk_relationships = {
        { from_table = "Categories", from_schema = "dbo", from_column = "CategoryID", to_table = "Categories", to_schema = "dbo", to_column = "CategoryID" },
      },
      max_depth = 2,
    },
    expected = {
      hop_count_1 = {},
      hop_count_2 = {},
    },
  },
  {
    id = 3908,
    type = "fk_graph",
    name = "Reverse FK direction not followed",
    input = {
      source_tables = { { name = "Departments", schema = "dbo" } },
      fk_relationships = {
        { from_table = "Employees", from_schema = "dbo", from_column = "DepartmentID", to_table = "Departments", to_schema = "dbo", to_column = "DepartmentID" },
      },
      max_depth = 2,
    },
    expected = {
      hop_count_1 = {},
      hop_count_2 = {},
    },
  },
  {
    id = 3909,
    type = "fk_graph",
    name = "Multi-column FK",
    input = {
      source_tables = { { name = "OrderDetails", schema = "dbo" } },
      fk_relationships = {
        { from_table = "OrderDetails", from_schema = "dbo", from_column = "OrderID, ProductID", to_table = "OrderProducts", to_schema = "dbo", to_column = "OrderID, ProductID" },
      },
      max_depth = 2,
    },
    expected = {
      hop_count_1 = { "OrderProducts" },
      hop_count_2 = {},
    },
  },
  {
    id = 3910,
    type = "fk_graph",
    name = "FK with different schemas",
    input = {
      source_tables = { { name = "Orders", schema = "sales" } },
      fk_relationships = {
        { from_table = "Orders", from_schema = "sales", from_column = "CustomerID", to_table = "Customers", to_schema = "crm", to_column = "CustomerID" },
      },
      max_depth = 2,
    },
    expected = {
      hop_count_1 = { "Customers" },
      hop_count_2 = {},
    },
  },
  {
    id = 3911,
    type = "fk_graph",
    name = "Circular FK handling",
    input = {
      source_tables = { { name = "A", schema = "dbo" } },
      fk_relationships = {
        { from_table = "A", from_schema = "dbo", from_column = "BID", to_table = "B", to_schema = "dbo", to_column = "BID" },
        { from_table = "B", from_schema = "dbo", from_column = "AID", to_table = "A", to_schema = "dbo", to_column = "AID" },
      },
      max_depth = 3,
    },
    expected = {
      hop_count_1 = { "B" },
      hop_count_2 = {},
      hop_count_3 = {},
    },
  },
  {
    id = 3912,
    type = "fk_graph",
    name = "FK constraint naming preserved",
    input = {
      source_tables = { { name = "Orders", schema = "dbo" } },
      fk_relationships = {
        { from_table = "Orders", from_schema = "dbo", from_column = "CustomerID", to_table = "Customers", to_schema = "dbo", to_column = "CustomerID", constraint_name = "FK_Orders_Customers" },
      },
      max_depth = 2,
    },
    expected = {
      hop_count_1 = { "Customers" },
      hop_count_2 = {},
      constraint_name = "FK_Orders_Customers",
    },
  },
  {
    id = 3913,
    type = "fk_graph",
    name = "FK column extraction",
    input = {
      source_tables = { { name = "Orders", schema = "dbo" } },
      fk_relationships = {
        { from_table = "Orders", from_schema = "dbo", from_column = "CustomerID", to_table = "Customers", to_schema = "dbo", to_column = "CustomerID" },
      },
      max_depth = 2,
    },
    expected = {
      hop_count_1 = { "Customers" },
      hop_count_2 = {},
      from_column = "CustomerID",
      to_column = "CustomerID",
    },
  },
  {
    id = 3914,
    type = "fk_graph",
    name = "Referenced column extraction",
    input = {
      source_tables = { { name = "Employees", schema = "dbo" } },
      fk_relationships = {
        { from_table = "Employees", from_schema = "dbo", from_column = "DeptCode", to_table = "Departments", to_schema = "dbo", to_column = "Code" },
      },
      max_depth = 2,
    },
    expected = {
      hop_count_1 = { "Departments" },
      hop_count_2 = {},
      from_column = "DeptCode",
      to_column = "Code",
    },
  },
  {
    id = 3915,
    type = "fk_graph",
    name = "Empty source tables",
    input = {
      source_tables = {},
      fk_relationships = {
        { from_table = "Orders", from_schema = "dbo", from_column = "CustomerID", to_table = "Customers", to_schema = "dbo", to_column = "CustomerID" },
      },
      max_depth = 2,
    },
    expected = {
      hop_count_1 = {},
      hop_count_2 = {},
    },
  },
  {
    id = 3916,
    type = "fk_graph",
    name = "Nil source tables",
    input = {
      source_tables = nil,
      fk_relationships = {
        { from_table = "Orders", from_schema = "dbo", from_column = "CustomerID", to_table = "Customers", to_schema = "dbo", to_column = "CustomerID" },
      },
      max_depth = 2,
    },
    expected = {
      hop_count_1 = {},
      hop_count_2 = {},
    },
  },
  {
    id = 3917,
    type = "fk_graph",
    name = "Max depth 1",
    input = {
      source_tables = { { name = "Orders", schema = "dbo" } },
      fk_relationships = {
        { from_table = "Orders", from_schema = "dbo", from_column = "CustomerID", to_table = "Customers", to_schema = "dbo", to_column = "CustomerID" },
        { from_table = "Customers", from_schema = "dbo", from_column = "CountryID", to_table = "Countries", to_schema = "dbo", to_column = "CountryID" },
      },
      max_depth = 1,
    },
    expected = {
      hop_count_1 = { "Customers" },
    },
  },
  {
    id = 3918,
    type = "fk_graph",
    name = "Max depth 0",
    input = {
      source_tables = { { name = "Orders", schema = "dbo" } },
      fk_relationships = {
        { from_table = "Orders", from_schema = "dbo", from_column = "CustomerID", to_table = "Customers", to_schema = "dbo", to_column = "CustomerID" },
      },
      max_depth = 0,
    },
    expected = {},
  },
  {
    id = 3919,
    type = "fk_graph",
    name = "Source table already visited",
    input = {
      source_tables = { { name = "Orders", schema = "dbo" } },
      fk_relationships = {
        { from_table = "Orders", from_schema = "dbo", from_column = "CustomerID", to_table = "Customers", to_schema = "dbo", to_column = "CustomerID" },
        { from_table = "Customers", from_schema = "dbo", from_column = "OrderID", to_table = "Orders", to_schema = "dbo", to_column = "OrderID" },
      },
      max_depth = 3,
    },
    expected = {
      hop_count_1 = { "Customers" },
      hop_count_2 = {},
      hop_count_3 = {},
    },
  },
  {
    id = 3920,
    type = "fk_graph",
    name = "Duplicate FK targets",
    input = {
      source_tables = { { name = "Orders", schema = "dbo" } },
      fk_relationships = {
        { from_table = "Orders", from_schema = "dbo", from_column = "CustomerID", to_table = "Customers", to_schema = "dbo", to_column = "CustomerID" },
        { from_table = "Orders", from_schema = "dbo", from_column = "BillingCustomerID", to_table = "Customers", to_schema = "dbo", to_column = "CustomerID" },
      },
      max_depth = 2,
    },
    expected = {
      hop_count_1 = { "Customers" },
      hop_count_2 = {},
      duplicate_paths = true,
    },
  },
  {
    id = 3921,
    type = "fk_graph",
    name = "FK with NULL schema",
    input = {
      source_tables = { { name = "Orders", schema = nil } },
      fk_relationships = {
        { from_table = "Orders", from_schema = nil, from_column = "CustomerID", to_table = "Customers", to_schema = nil, to_column = "CustomerID" },
      },
      max_depth = 2,
    },
    expected = {
      hop_count_1 = { "Customers" },
      hop_count_2 = {},
    },
  },
  {
    id = 3922,
    type = "fk_graph",
    name = "FK case sensitivity",
    input = {
      source_tables = { { name = "orders", schema = "dbo" } },
      fk_relationships = {
        { from_table = "Orders", from_schema = "dbo", from_column = "CustomerID", to_table = "Customers", to_schema = "dbo", to_column = "CustomerID" },
      },
      max_depth = 2,
    },
    expected = {
      hop_count_1 = {},
      hop_count_2 = {},
    },
  },
  {
    id = 3923,
    type = "fk_graph",
    name = "FK with spaces in table name",
    input = {
      source_tables = { { name = "Order Details", schema = "dbo" } },
      fk_relationships = {
        { from_table = "Order Details", from_schema = "dbo", from_column = "OrderID", to_table = "Orders", to_schema = "dbo", to_column = "OrderID" },
      },
      max_depth = 2,
    },
    expected = {
      hop_count_1 = { "Orders" },
      hop_count_2 = {},
    },
  },
  {
    id = 3924,
    type = "fk_graph",
    name = "FK with special characters",
    input = {
      source_tables = { { name = "Products_2024", schema = "dbo" } },
      fk_relationships = {
        { from_table = "Products_2024", from_schema = "dbo", from_column = "CategoryID", to_table = "Categories", to_schema = "dbo", to_column = "CategoryID" },
      },
      max_depth = 2,
    },
    expected = {
      hop_count_1 = { "Categories" },
      hop_count_2 = {},
    },
  },
  {
    id = 3925,
    type = "fk_graph",
    name = "FK with numeric table name",
    input = {
      source_tables = { { name = "2024_Orders", schema = "dbo" } },
      fk_relationships = {
        { from_table = "2024_Orders", from_schema = "dbo", from_column = "CustomerID", to_table = "Customers", to_schema = "dbo", to_column = "CustomerID" },
      },
      max_depth = 2,
    },
    expected = {
      hop_count_1 = { "Customers" },
      hop_count_2 = {},
    },
  },
  {
    id = 3926,
    type = "fk_graph",
    name = "FK with unicode table name",
    input = {
      source_tables = { { name = "顧客", schema = "dbo" } },
      fk_relationships = {
        { from_table = "顧客", from_schema = "dbo", from_column = "国ID", to_table = "国", to_schema = "dbo", to_column = "ID" },
      },
      max_depth = 2,
    },
    expected = {
      hop_count_1 = { "国" },
      hop_count_2 = {},
    },
  },
  {
    id = 3927,
    type = "fk_graph",
    name = "FK with very long table name",
    input = {
      source_tables = { { name = "VeryLongTableNameThatExceedsNormalLengthButIsStillValid", schema = "dbo" } },
      fk_relationships = {
        { from_table = "VeryLongTableNameThatExceedsNormalLengthButIsStillValid", from_schema = "dbo", from_column = "ID", to_table = "ShortTable", to_schema = "dbo", to_column = "ID" },
      },
      max_depth = 2,
    },
    expected = {
      hop_count_1 = { "ShortTable" },
      hop_count_2 = {},
    },
  },
  {
    id = 3928,
    type = "fk_graph",
    name = "FK with database prefix ignored",
    input = {
      source_tables = { { name = "Orders", schema = "dbo", database = "SalesDB" } },
      fk_relationships = {
        { from_table = "Orders", from_schema = "dbo", from_column = "CustomerID", to_table = "Customers", to_schema = "dbo", to_column = "CustomerID" },
      },
      max_depth = 2,
    },
    expected = {
      hop_count_1 = { "Customers" },
      hop_count_2 = {},
    },
  },
  {
    id = 3929,
    type = "fk_graph",
    name = "FK partial match ignored",
    input = {
      source_tables = { { name = "OrderDetails", schema = "dbo" } },
      fk_relationships = {
        { from_table = "Order", from_schema = "dbo", from_column = "CustomerID", to_table = "Customers", to_schema = "dbo", to_column = "CustomerID" },
      },
      max_depth = 2,
    },
    expected = {
      hop_count_1 = {},
      hop_count_2 = {},
    },
  },
  {
    id = 3930,
    type = "fk_graph",
    name = "FK with empty constraint name",
    input = {
      source_tables = { { name = "Orders", schema = "dbo" } },
      fk_relationships = {
        { from_table = "Orders", from_schema = "dbo", from_column = "CustomerID", to_table = "Customers", to_schema = "dbo", to_column = "CustomerID", constraint_name = "" },
      },
      max_depth = 2,
    },
    expected = {
      hop_count_1 = { "Customers" },
      hop_count_2 = {},
    },
  },

  -- Multi-Hop FK Chains (3931-3960)
  {
    id = 3931,
    type = "fk_graph",
    name = "2-hop chain A -> B -> C",
    input = {
      source_tables = { { name = "Orders", schema = "dbo" } },
      fk_relationships = {
        { from_table = "Orders", from_schema = "dbo", from_column = "CustomerID", to_table = "Customers", to_schema = "dbo", to_column = "CustomerID" },
        { from_table = "Customers", from_schema = "dbo", from_column = "CountryID", to_table = "Countries", to_schema = "dbo", to_column = "CountryID" },
      },
      max_depth = 2,
    },
    expected = {
      hop_count_1 = { "Customers" },
      hop_count_2 = { "Countries" },
    },
  },
  {
    id = 3932,
    type = "fk_graph",
    name = "2-hop multiple paths",
    input = {
      source_tables = { { name = "Orders", schema = "dbo" } },
      fk_relationships = {
        { from_table = "Orders", from_schema = "dbo", from_column = "CustomerID", to_table = "Customers", to_schema = "dbo", to_column = "CustomerID" },
        { from_table = "Orders", from_schema = "dbo", from_column = "ProductID", to_table = "Products", to_schema = "dbo", to_column = "ProductID" },
        { from_table = "Customers", from_schema = "dbo", from_column = "CountryID", to_table = "Countries", to_schema = "dbo", to_column = "CountryID" },
        { from_table = "Products", from_schema = "dbo", from_column = "CategoryID", to_table = "Categories", to_schema = "dbo", to_column = "CategoryID" },
      },
      max_depth = 2,
    },
    expected = {
      hop_count_1 = { "Customers", "Products" },
      hop_count_2 = { "Countries", "Categories" },
    },
  },
  {
    id = 3933,
    type = "fk_graph",
    name = "3-hop chain limited by default max",
    input = {
      source_tables = { { name = "OrderDetails", schema = "dbo" } },
      fk_relationships = {
        { from_table = "OrderDetails", from_schema = "dbo", from_column = "OrderID", to_table = "Orders", to_schema = "dbo", to_column = "OrderID" },
        { from_table = "Orders", from_schema = "dbo", from_column = "CustomerID", to_table = "Customers", to_schema = "dbo", to_column = "CustomerID" },
        { from_table = "Customers", from_schema = "dbo", from_column = "CountryID", to_table = "Countries", to_schema = "dbo", to_column = "CountryID" },
      },
      max_depth = 3,
    },
    expected = {
      hop_count_1 = { "Orders" },
      hop_count_2 = { "Customers" },
      hop_count_3 = { "Countries" },
    },
  },
  {
    id = 3934,
    type = "fk_graph",
    name = "Diamond FK pattern",
    input = {
      source_tables = { { name = "Orders", schema = "dbo" } },
      fk_relationships = {
        { from_table = "Orders", from_schema = "dbo", from_column = "CustomerID", to_table = "Customers", to_schema = "dbo", to_column = "CustomerID" },
        { from_table = "Orders", from_schema = "dbo", from_column = "ProductID", to_table = "Products", to_schema = "dbo", to_column = "ProductID" },
        { from_table = "Customers", from_schema = "dbo", from_column = "RegionID", to_table = "Regions", to_schema = "dbo", to_column = "RegionID" },
        { from_table = "Products", from_schema = "dbo", from_column = "RegionID", to_table = "Regions", to_schema = "dbo", to_column = "RegionID" },
      },
      max_depth = 2,
    },
    expected = {
      hop_count_1 = { "Customers", "Products" },
      hop_count_2 = { "Regions" },
      duplicate_targets = true,
    },
  },
  {
    id = 3935,
    type = "fk_graph",
    name = "Tree FK pattern",
    input = {
      source_tables = { { name = "Employees", schema = "dbo" } },
      fk_relationships = {
        { from_table = "Employees", from_schema = "dbo", from_column = "DepartmentID", to_table = "Departments", to_schema = "dbo", to_column = "DepartmentID" },
        { from_table = "Departments", from_schema = "dbo", from_column = "DivisionID", to_table = "Divisions", to_schema = "dbo", to_column = "DivisionID" },
        { from_table = "Departments", from_schema = "dbo", from_column = "LocationID", to_table = "Locations", to_schema = "dbo", to_column = "LocationID" },
      },
      max_depth = 2,
    },
    expected = {
      hop_count_1 = { "Departments" },
      hop_count_2 = { "Divisions", "Locations" },
    },
  },
  {
    id = 3936,
    type = "fk_graph",
    name = "Cycle detection",
    input = {
      source_tables = { { name = "A", schema = "dbo" } },
      fk_relationships = {
        { from_table = "A", from_schema = "dbo", from_column = "BID", to_table = "B", to_schema = "dbo", to_column = "BID" },
        { from_table = "B", from_schema = "dbo", from_column = "CID", to_table = "C", to_schema = "dbo", to_column = "CID" },
        { from_table = "C", from_schema = "dbo", from_column = "AID", to_table = "A", to_schema = "dbo", to_column = "AID" },
      },
      max_depth = 3,
    },
    expected = {
      hop_count_1 = { "B" },
      hop_count_2 = { "C" },
      hop_count_3 = {},
    },
  },
  {
    id = 3937,
    type = "fk_graph",
    name = "Revisit prevention",
    input = {
      source_tables = { { name = "Orders", schema = "dbo" } },
      fk_relationships = {
        { from_table = "Orders", from_schema = "dbo", from_column = "CustomerID", to_table = "Customers", to_schema = "dbo", to_column = "CustomerID" },
        { from_table = "Orders", from_schema = "dbo", from_column = "ProductID", to_table = "Products", to_schema = "dbo", to_column = "ProductID" },
        { from_table = "Customers", from_schema = "dbo", from_column = "ProductID", to_table = "Products", to_schema = "dbo", to_column = "ProductID" },
      },
      max_depth = 2,
    },
    expected = {
      hop_count_1 = { "Customers", "Products" },
      hop_count_2 = {},
    },
  },
  {
    id = 3938,
    type = "fk_graph",
    name = "Path tracking accuracy",
    input = {
      source_tables = { { name = "Orders", schema = "dbo" } },
      fk_relationships = {
        { from_table = "Orders", from_schema = "dbo", from_column = "CustomerID", to_table = "Customers", to_schema = "dbo", to_column = "CustomerID" },
        { from_table = "Customers", from_schema = "dbo", from_column = "CountryID", to_table = "Countries", to_schema = "dbo", to_column = "CountryID" },
      },
      max_depth = 2,
    },
    expected = {
      hop_count_1 = { "Customers" },
      hop_count_2 = { "Countries" },
      path_for_countries = { "Customers" },
    },
  },
  {
    id = 3939,
    type = "fk_graph",
    name = "Via table tracking",
    input = {
      source_tables = { { name = "Orders", schema = "dbo" } },
      fk_relationships = {
        { from_table = "Orders", from_schema = "dbo", from_column = "CustomerID", to_table = "Customers", to_schema = "dbo", to_column = "CustomerID" },
        { from_table = "Customers", from_schema = "dbo", from_column = "CountryID", to_table = "Countries", to_schema = "dbo", to_column = "CountryID" },
      },
      max_depth = 2,
    },
    expected = {
      hop_count_1 = { "Customers" },
      hop_count_2 = { "Countries" },
      via_table = "Customers",
    },
  },
  {
    id = 3940,
    type = "fk_graph",
    name = "Source table in path excluded",
    input = {
      source_tables = { { name = "Orders", schema = "dbo" } },
      fk_relationships = {
        { from_table = "Orders", from_schema = "dbo", from_column = "CustomerID", to_table = "Customers", to_schema = "dbo", to_column = "CustomerID" },
        { from_table = "Customers", from_schema = "dbo", from_column = "OrderID", to_table = "Orders", to_schema = "dbo", to_column = "OrderID" },
      },
      max_depth = 2,
    },
    expected = {
      hop_count_1 = { "Customers" },
      hop_count_2 = {},
    },
  },
  {
    id = 3941,
    type = "fk_graph",
    name = "Max depth 2 limits",
    input = {
      source_tables = { { name = "A", schema = "dbo" } },
      fk_relationships = {
        { from_table = "A", from_schema = "dbo", from_column = "BID", to_table = "B", to_schema = "dbo", to_column = "BID" },
        { from_table = "B", from_schema = "dbo", from_column = "CID", to_table = "C", to_schema = "dbo", to_column = "CID" },
        { from_table = "C", from_schema = "dbo", from_column = "DID", to_table = "D", to_schema = "dbo", to_column = "DID" },
      },
      max_depth = 2,
    },
    expected = {
      hop_count_1 = { "B" },
      hop_count_2 = { "C" },
    },
  },
  {
    id = 3942,
    type = "fk_graph",
    name = "Max depth 3 allows more",
    input = {
      source_tables = { { name = "A", schema = "dbo" } },
      fk_relationships = {
        { from_table = "A", from_schema = "dbo", from_column = "BID", to_table = "B", to_schema = "dbo", to_column = "BID" },
        { from_table = "B", from_schema = "dbo", from_column = "CID", to_table = "C", to_schema = "dbo", to_column = "CID" },
        { from_table = "C", from_schema = "dbo", from_column = "DID", to_table = "D", to_schema = "dbo", to_column = "DID" },
      },
      max_depth = 3,
    },
    expected = {
      hop_count_1 = { "B" },
      hop_count_2 = { "C" },
      hop_count_3 = { "D" },
    },
  },
  {
    id = 3943,
    type = "fk_graph",
    name = "Hop count accuracy",
    input = {
      source_tables = { { name = "Orders", schema = "dbo" } },
      fk_relationships = {
        { from_table = "Orders", from_schema = "dbo", from_column = "CustomerID", to_table = "Customers", to_schema = "dbo", to_column = "CustomerID" },
        { from_table = "Customers", from_schema = "dbo", from_column = "CountryID", to_table = "Countries", to_schema = "dbo", to_column = "CountryID" },
        { from_table = "Countries", from_schema = "dbo", from_column = "RegionID", to_table = "Regions", to_schema = "dbo", to_column = "RegionID" },
      },
      max_depth = 3,
    },
    expected = {
      hop_count_1 = { "Customers" },
      hop_count_2 = { "Countries" },
      hop_count_3 = { "Regions" },
      customers_hops = 1,
      countries_hops = 2,
      regions_hops = 3,
    },
  },
  {
    id = 3944,
    type = "fk_graph",
    name = "Multi-source multi-hop",
    input = {
      source_tables = {
        { name = "Orders", schema = "dbo" },
        { name = "Products", schema = "dbo" },
      },
      fk_relationships = {
        { from_table = "Orders", from_schema = "dbo", from_column = "CustomerID", to_table = "Customers", to_schema = "dbo", to_column = "CustomerID" },
        { from_table = "Customers", from_schema = "dbo", from_column = "CountryID", to_table = "Countries", to_schema = "dbo", to_column = "CountryID" },
        { from_table = "Products", from_schema = "dbo", from_column = "CategoryID", to_table = "Categories", to_schema = "dbo", to_column = "CategoryID" },
        { from_table = "Categories", from_schema = "dbo", from_column = "DivisionID", to_table = "Divisions", to_schema = "dbo", to_column = "DivisionID" },
      },
      max_depth = 2,
    },
    expected = {
      hop_count_1 = { "Customers", "Categories" },
      hop_count_2 = { "Countries", "Divisions" },
    },
  },
  {
    id = 3945,
    type = "fk_graph",
    name = "FK chain with schemas",
    input = {
      source_tables = { { name = "Orders", schema = "sales" } },
      fk_relationships = {
        { from_table = "Orders", from_schema = "sales", from_column = "CustomerID", to_table = "Customers", to_schema = "crm", to_column = "CustomerID" },
        { from_table = "Customers", from_schema = "crm", from_column = "CountryID", to_table = "Countries", to_schema = "geo", to_column = "CountryID" },
      },
      max_depth = 2,
    },
    expected = {
      hop_count_1 = { "Customers" },
      hop_count_2 = { "Countries" },
    },
  },
  {
    id = 3946,
    type = "fk_graph",
    name = "FK chain with databases ignored",
    input = {
      source_tables = { { name = "Orders", schema = "dbo", database = "SalesDB" } },
      fk_relationships = {
        { from_table = "Orders", from_schema = "dbo", from_column = "CustomerID", to_table = "Customers", to_schema = "dbo", to_column = "CustomerID" },
        { from_table = "Customers", from_schema = "dbo", from_column = "CountryID", to_table = "Countries", to_schema = "dbo", to_column = "CountryID" },
      },
      max_depth = 2,
    },
    expected = {
      hop_count_1 = { "Customers" },
      hop_count_2 = { "Countries" },
    },
  },
  {
    id = 3947,
    type = "fk_graph",
    name = "Long chain truncation",
    input = {
      source_tables = { { name = "A", schema = "dbo" } },
      fk_relationships = {
        { from_table = "A", from_schema = "dbo", from_column = "BID", to_table = "B", to_schema = "dbo", to_column = "BID" },
        { from_table = "B", from_schema = "dbo", from_column = "CID", to_table = "C", to_schema = "dbo", to_column = "CID" },
        { from_table = "C", from_schema = "dbo", from_column = "DID", to_table = "D", to_schema = "dbo", to_column = "DID" },
        { from_table = "D", from_schema = "dbo", from_column = "EID", to_table = "E", to_schema = "dbo", to_column = "EID" },
      },
      max_depth = 3,
    },
    expected = {
      hop_count_1 = { "B" },
      hop_count_2 = { "C" },
      hop_count_3 = { "D" },
      truncated = true,
    },
  },
  {
    id = 3948,
    type = "fk_graph",
    name = "Parallel chains",
    input = {
      source_tables = { { name = "Orders", schema = "dbo" } },
      fk_relationships = {
        { from_table = "Orders", from_schema = "dbo", from_column = "CustomerID", to_table = "Customers", to_schema = "dbo", to_column = "CustomerID" },
        { from_table = "Customers", from_schema = "dbo", from_column = "CountryID", to_table = "Countries", to_schema = "dbo", to_column = "CountryID" },
        { from_table = "Orders", from_schema = "dbo", from_column = "ShipperID", to_table = "Shippers", to_schema = "dbo", to_column = "ShipperID" },
        { from_table = "Shippers", from_schema = "dbo", from_column = "CountryID", to_table = "Countries", to_schema = "dbo", to_column = "CountryID" },
      },
      max_depth = 2,
    },
    expected = {
      hop_count_1 = { "Customers", "Shippers" },
      hop_count_2 = { "Countries" },
    },
  },
  {
    id = 3949,
    type = "fk_graph",
    name = "Merging chains",
    input = {
      source_tables = { { name = "A", schema = "dbo" }, { name = "B", schema = "dbo" } },
      fk_relationships = {
        { from_table = "A", from_schema = "dbo", from_column = "CID", to_table = "C", to_schema = "dbo", to_column = "CID" },
        { from_table = "B", from_schema = "dbo", from_column = "CID", to_table = "C", to_schema = "dbo", to_column = "CID" },
        { from_table = "C", from_schema = "dbo", from_column = "DID", to_table = "D", to_schema = "dbo", to_column = "DID" },
      },
      max_depth = 2,
    },
    expected = {
      hop_count_1 = { "C" },
      hop_count_2 = { "D" },
    },
  },
  {
    id = 3950,
    type = "fk_graph",
    name = "Performance with many tables",
    input = {
      source_tables = { { name = "Orders", schema = "dbo" } },
      fk_relationships = {
        { from_table = "Orders", from_schema = "dbo", from_column = "C1", to_table = "T1", to_schema = "dbo", to_column = "ID" },
        { from_table = "Orders", from_schema = "dbo", from_column = "C2", to_table = "T2", to_schema = "dbo", to_column = "ID" },
        { from_table = "Orders", from_schema = "dbo", from_column = "C3", to_table = "T3", to_schema = "dbo", to_column = "ID" },
        { from_table = "Orders", from_schema = "dbo", from_column = "C4", to_table = "T4", to_schema = "dbo", to_column = "ID" },
        { from_table = "Orders", from_schema = "dbo", from_column = "C5", to_table = "T5", to_schema = "dbo", to_column = "ID" },
        { from_table = "T1", from_schema = "dbo", from_column = "X1", to_table = "X1", to_schema = "dbo", to_column = "ID" },
        { from_table = "T2", from_schema = "dbo", from_column = "X2", to_table = "X2", to_schema = "dbo", to_column = "ID" },
        { from_table = "T3", from_schema = "dbo", from_column = "X3", to_table = "X3", to_schema = "dbo", to_column = "ID" },
        { from_table = "T4", from_schema = "dbo", from_column = "X4", to_table = "X4", to_schema = "dbo", to_column = "ID" },
        { from_table = "T5", from_schema = "dbo", from_column = "X5", to_table = "X5", to_schema = "dbo", to_column = "ID" },
      },
      max_depth = 2,
    },
    expected = {
      hop_count_1 = { "T1", "T2", "T3", "T4", "T5" },
      hop_count_2 = { "X1", "X2", "X3", "X4", "X5" },
    },
  },
  {
    id = 3951,
    type = "fk_graph",
    name = "Chain with intermediate self-reference",
    input = {
      source_tables = { { name = "Orders", schema = "dbo" } },
      fk_relationships = {
        { from_table = "Orders", from_schema = "dbo", from_column = "CustomerID", to_table = "Customers", to_schema = "dbo", to_column = "CustomerID" },
        { from_table = "Customers", from_schema = "dbo", from_column = "ParentID", to_table = "Customers", to_schema = "dbo", to_column = "CustomerID" },
        { from_table = "Customers", from_schema = "dbo", from_column = "CountryID", to_table = "Countries", to_schema = "dbo", to_column = "CountryID" },
      },
      max_depth = 2,
    },
    expected = {
      hop_count_1 = { "Customers" },
      hop_count_2 = { "Countries" },
    },
  },
  {
    id = 3952,
    type = "fk_graph",
    name = "Wide breadth at first hop",
    input = {
      source_tables = { { name = "Orders", schema = "dbo" } },
      fk_relationships = {
        { from_table = "Orders", from_schema = "dbo", from_column = "C1", to_table = "T1", to_schema = "dbo", to_column = "ID" },
        { from_table = "Orders", from_schema = "dbo", from_column = "C2", to_table = "T2", to_schema = "dbo", to_column = "ID" },
        { from_table = "Orders", from_schema = "dbo", from_column = "C3", to_table = "T3", to_schema = "dbo", to_column = "ID" },
        { from_table = "Orders", from_schema = "dbo", from_column = "C4", to_table = "T4", to_schema = "dbo", to_column = "ID" },
        { from_table = "Orders", from_schema = "dbo", from_column = "C5", to_table = "T5", to_schema = "dbo", to_column = "ID" },
        { from_table = "Orders", from_schema = "dbo", from_column = "C6", to_table = "T6", to_schema = "dbo", to_column = "ID" },
        { from_table = "Orders", from_schema = "dbo", from_column = "C7", to_table = "T7", to_schema = "dbo", to_column = "ID" },
        { from_table = "Orders", from_schema = "dbo", from_column = "C8", to_table = "T8", to_schema = "dbo", to_column = "ID" },
      },
      max_depth = 2,
    },
    expected = {
      hop_count_1 = { "T1", "T2", "T3", "T4", "T5", "T6", "T7", "T8" },
      hop_count_2 = {},
    },
  },
  {
    id = 3953,
    type = "fk_graph",
    name = "Deep chain single path",
    input = {
      source_tables = { { name = "A", schema = "dbo" } },
      fk_relationships = {
        { from_table = "A", from_schema = "dbo", from_column = "BID", to_table = "B", to_schema = "dbo", to_column = "ID" },
        { from_table = "B", from_schema = "dbo", from_column = "CID", to_table = "C", to_schema = "dbo", to_column = "ID" },
        { from_table = "C", from_schema = "dbo", from_column = "DID", to_table = "D", to_schema = "dbo", to_column = "ID" },
      },
      max_depth = 3,
    },
    expected = {
      hop_count_1 = { "B" },
      hop_count_2 = { "C" },
      hop_count_3 = { "D" },
    },
  },
  {
    id = 3954,
    type = "fk_graph",
    name = "Multiple sources converging",
    input = {
      source_tables = {
        { name = "Orders", schema = "dbo" },
        { name = "Invoices", schema = "dbo" },
      },
      fk_relationships = {
        { from_table = "Orders", from_schema = "dbo", from_column = "CustomerID", to_table = "Customers", to_schema = "dbo", to_column = "CustomerID" },
        { from_table = "Invoices", from_schema = "dbo", from_column = "CustomerID", to_table = "Customers", to_schema = "dbo", to_column = "CustomerID" },
        { from_table = "Customers", from_schema = "dbo", from_column = "CountryID", to_table = "Countries", to_schema = "dbo", to_column = "CountryID" },
      },
      max_depth = 2,
    },
    expected = {
      hop_count_1 = { "Customers" },
      hop_count_2 = { "Countries" },
    },
  },
  {
    id = 3955,
    type = "fk_graph",
    name = "Complex multi-path scenario",
    input = {
      source_tables = { { name = "Orders", schema = "dbo" } },
      fk_relationships = {
        { from_table = "Orders", from_schema = "dbo", from_column = "CustomerID", to_table = "Customers", to_schema = "dbo", to_column = "CustomerID" },
        { from_table = "Orders", from_schema = "dbo", from_column = "ProductID", to_table = "Products", to_schema = "dbo", to_column = "ProductID" },
        { from_table = "Orders", from_schema = "dbo", from_column = "ShipperID", to_table = "Shippers", to_schema = "dbo", to_column = "ShipperID" },
        { from_table = "Customers", from_schema = "dbo", from_column = "CountryID", to_table = "Countries", to_schema = "dbo", to_column = "CountryID" },
        { from_table = "Products", from_schema = "dbo", from_column = "SupplierID", to_table = "Suppliers", to_schema = "dbo", to_column = "SupplierID" },
        { from_table = "Shippers", from_schema = "dbo", from_column = "CountryID", to_table = "Countries", to_schema = "dbo", to_column = "CountryID" },
      },
      max_depth = 2,
    },
    expected = {
      hop_count_1 = { "Customers", "Products", "Shippers" },
      hop_count_2 = { "Countries", "Suppliers" },
    },
  },
  {
    id = 3956,
    type = "fk_graph",
    name = "Chain with missing intermediate FK",
    input = {
      source_tables = { { name = "Orders", schema = "dbo" } },
      fk_relationships = {
        { from_table = "Orders", from_schema = "dbo", from_column = "CustomerID", to_table = "Customers", to_schema = "dbo", to_column = "CustomerID" },
        { from_table = "Countries", from_schema = "dbo", from_column = "RegionID", to_table = "Regions", to_schema = "dbo", to_column = "RegionID" },
      },
      max_depth = 3,
    },
    expected = {
      hop_count_1 = { "Customers" },
      hop_count_2 = {},
      hop_count_3 = {},
    },
  },
  {
    id = 3957,
    type = "fk_graph",
    name = "Bidirectional FK ignored",
    input = {
      source_tables = { { name = "Orders", schema = "dbo" } },
      fk_relationships = {
        { from_table = "Orders", from_schema = "dbo", from_column = "CustomerID", to_table = "Customers", to_schema = "dbo", to_column = "CustomerID" },
        { from_table = "Customers", from_schema = "dbo", from_column = "LastOrderID", to_table = "Orders", to_schema = "dbo", to_column = "OrderID" },
      },
      max_depth = 2,
    },
    expected = {
      hop_count_1 = { "Customers" },
      hop_count_2 = {},
    },
  },
  {
    id = 3958,
    type = "fk_graph",
    name = "Exponential path growth",
    input = {
      source_tables = { { name = "A", schema = "dbo" } },
      fk_relationships = {
        { from_table = "A", from_schema = "dbo", from_column = "B1", to_table = "B1", to_schema = "dbo", to_column = "ID" },
        { from_table = "A", from_schema = "dbo", from_column = "B2", to_table = "B2", to_schema = "dbo", to_column = "ID" },
        { from_table = "B1", from_schema = "dbo", from_column = "C1", to_table = "C1", to_schema = "dbo", to_column = "ID" },
        { from_table = "B1", from_schema = "dbo", from_column = "C2", to_table = "C2", to_schema = "dbo", to_column = "ID" },
        { from_table = "B2", from_schema = "dbo", from_column = "C3", to_table = "C3", to_schema = "dbo", to_column = "ID" },
        { from_table = "B2", from_schema = "dbo", from_column = "C4", to_table = "C4", to_schema = "dbo", to_column = "ID" },
      },
      max_depth = 2,
    },
    expected = {
      hop_count_1 = { "B1", "B2" },
      hop_count_2 = { "C1", "C2", "C3", "C4" },
    },
  },
  {
    id = 3959,
    type = "fk_graph",
    name = "Empty FKs at intermediate hop",
    input = {
      source_tables = { { name = "Orders", schema = "dbo" } },
      fk_relationships = {
        { from_table = "Orders", from_schema = "dbo", from_column = "CustomerID", to_table = "Customers", to_schema = "dbo", to_column = "CustomerID" },
      },
      max_depth = 3,
    },
    expected = {
      hop_count_1 = { "Customers" },
      hop_count_2 = {},
      hop_count_3 = {},
    },
  },
  {
    id = 3960,
    type = "fk_graph",
    name = "Chain with mixed hop depths",
    input = {
      source_tables = { { name = "Orders", schema = "dbo" } },
      fk_relationships = {
        { from_table = "Orders", from_schema = "dbo", from_column = "CustomerID", to_table = "Customers", to_schema = "dbo", to_column = "CustomerID" },
        { from_table = "Orders", from_schema = "dbo", from_column = "StatusID", to_table = "Statuses", to_schema = "dbo", to_column = "StatusID" },
        { from_table = "Customers", from_schema = "dbo", from_column = "CountryID", to_table = "Countries", to_schema = "dbo", to_column = "CountryID" },
        { from_table = "Countries", from_schema = "dbo", from_column = "RegionID", to_table = "Regions", to_schema = "dbo", to_column = "RegionID" },
      },
      max_depth = 3,
    },
    expected = {
      hop_count_1 = { "Customers", "Statuses" },
      hop_count_2 = { "Countries" },
      hop_count_3 = { "Regions" },
    },
  },

  -- Label and Detail Building (3961-3980)
  {
    id = 3961,
    type = "fk_graph",
    name = "Label for 1-hop just table name",
    input = {
      result = {
        target_table = "Customers",
        hop_count = 1,
        path = {},
      },
    },
    expected = {
      label = "Customers",
    },
  },
  {
    id = 3962,
    type = "fk_graph",
    name = "Label for 2-hop via intermediate",
    input = {
      result = {
        target_table = "Countries",
        hop_count = 2,
        path = { "Customers" },
      },
    },
    expected = {
      label = "Countries (via Customers)",
    },
  },
  {
    id = 3963,
    type = "fk_graph",
    name = "Label for 3-hop via last intermediate",
    input = {
      result = {
        target_table = "Regions",
        hop_count = 3,
        path = { "Customers", "Countries" },
      },
    },
    expected = {
      label = "Regions (via Countries)",
    },
  },
  {
    id = 3964,
    type = "fk_graph",
    name = "Detail for 1-hop JOIN suggestion FK",
    input = {
      result = {
        target_table = "Customers",
        hop_count = 1,
        path = {},
      },
    },
    expected = {
      detail = "JOIN suggestion (FK)",
    },
  },
  {
    id = 3965,
    type = "fk_graph",
    name = "Detail for 2-hop includes hop count",
    input = {
      result = {
        target_table = "Countries",
        hop_count = 2,
        path = { "Customers" },
      },
    },
    expected = {
      detail = "JOIN suggestion (FK, 2 hops)",
    },
  },
  {
    id = 3966,
    type = "fk_graph",
    name = "Detail for 3-hop includes hop count",
    input = {
      result = {
        target_table = "Regions",
        hop_count = 3,
        path = { "Customers", "Countries" },
      },
    },
    expected = {
      detail = "JOIN suggestion (FK, 3 hops)",
    },
  },
  {
    id = 3967,
    type = "fk_graph",
    name = "Documentation 1-hop format",
    input = {
      result = {
        target_table = "Customers",
        target_schema = "dbo",
        hop_count = 1,
        path = {},
        from_column = "CustomerID",
        to_column = "CustomerID",
      },
    },
    expected = {
      documentation = "**JOIN via Foreign Key**\n\nDirect FK relationship:\n- `CustomerID` → `dbo.Customers.CustomerID`",
    },
  },
  {
    id = 3968,
    type = "fk_graph",
    name = "Documentation multi-hop format",
    input = {
      result = {
        target_table = "Countries",
        target_schema = "dbo",
        hop_count = 2,
        path = { "Customers" },
        from_column = "CustomerID",
        to_column = "CountryID",
      },
    },
    expected = {
      documentation = "**JOIN via Foreign Key Chain**\n\n2-hop path:\n- Orders → Customers → Countries\n\nFinal FK: `CustomerID` → `dbo.Countries.CountryID`",
    },
  },
  {
    id = 3969,
    type = "fk_graph",
    name = "Documentation FK columns shown",
    input = {
      result = {
        target_table = "Departments",
        target_schema = "hr",
        hop_count = 1,
        path = {},
        from_column = "DepartmentID",
        to_column = "DeptID",
      },
    },
    expected = {
      documentation = "**JOIN via Foreign Key**\n\nDirect FK relationship:\n- `DepartmentID` → `hr.Departments.DeptID`",
    },
  },
  {
    id = 3970,
    type = "fk_graph",
    name = "Documentation path shown",
    input = {
      result = {
        target_table = "Regions",
        target_schema = "geo",
        hop_count = 3,
        path = { "Customers", "Countries" },
        from_column = "CustomerID",
        to_column = "RegionID",
      },
    },
    expected = {
      documentation = "**JOIN via Foreign Key Chain**\n\n3-hop path:\n- Orders → Customers → Countries → Regions\n\nFinal FK: `CustomerID` → `geo.Regions.RegionID`",
    },
  },
  {
    id = 3971,
    type = "fk_graph",
    name = "Label with long table names",
    input = {
      result = {
        target_table = "VeryLongTableNameThatWillBeDisplayed",
        hop_count = 2,
        path = { "AnotherVeryLongIntermediateTableName" },
      },
    },
    expected = {
      label = "VeryLongTableNameThatWillBeDisplayed (via AnotherVeryLongIntermediateTableName)",
    },
  },
  {
    id = 3972,
    type = "fk_graph",
    name = "Label with schema prefix",
    input = {
      result = {
        target_table = "Customers",
        target_schema = "sales",
        hop_count = 1,
        path = {},
      },
    },
    expected = {
      label = "Customers",
    },
  },
  {
    id = 3973,
    type = "fk_graph",
    name = "Detail with constraint name",
    input = {
      result = {
        target_table = "Customers",
        hop_count = 1,
        path = {},
        constraint_name = "FK_Orders_Customers",
      },
    },
    expected = {
      detail = "JOIN suggestion (FK)",
    },
  },
  {
    id = 3974,
    type = "fk_graph",
    name = "Documentation with multi-column FK",
    input = {
      result = {
        target_table = "OrderProducts",
        target_schema = "dbo",
        hop_count = 1,
        path = {},
        from_column = "OrderID, ProductID",
        to_column = "OrderID, ProductID",
      },
    },
    expected = {
      documentation = "**JOIN via Foreign Key**\n\nDirect FK relationship:\n- `OrderID, ProductID` → `dbo.OrderProducts.OrderID, ProductID`",
    },
  },
  {
    id = 3975,
    type = "fk_graph",
    name = "Empty path handling",
    input = {
      result = {
        target_table = "Customers",
        hop_count = 1,
        path = nil,
      },
    },
    expected = {
      label = "Customers",
    },
  },
  {
    id = 3976,
    type = "fk_graph",
    name = "Nil fields handling",
    input = {
      result = {
        target_table = "Customers",
        hop_count = 1,
      },
    },
    expected = {
      label = "Customers",
      detail = "JOIN suggestion (FK)",
    },
  },
  {
    id = 3977,
    type = "fk_graph",
    name = "Label with empty via table",
    input = {
      result = {
        target_table = "Countries",
        hop_count = 2,
        path = { "" },
      },
    },
    expected = {
      label = "Countries",
    },
  },
  {
    id = 3978,
    type = "fk_graph",
    name = "Documentation with missing columns",
    input = {
      result = {
        target_table = "Customers",
        target_schema = "dbo",
        hop_count = 1,
        path = {},
      },
    },
    expected = {
      documentation = "**JOIN via Foreign Key**\n\nDirect FK relationship to `dbo.Customers`",
    },
  },
  {
    id = 3979,
    type = "fk_graph",
    name = "Label with nil via path entry",
    input = {
      result = {
        target_table = "Countries",
        hop_count = 2,
        path = { nil },
      },
    },
    expected = {
      label = "Countries",
    },
  },
  {
    id = 3980,
    type = "fk_graph",
    name = "Detail with zero hop count",
    input = {
      result = {
        target_table = "Customers",
        hop_count = 0,
        path = {},
      },
    },
    expected = {
      detail = "JOIN suggestion (FK)",
    },
  },

  -- Flatten and Sort (3981-4000)
  {
    id = 3981,
    type = "fk_graph",
    name = "Flatten empty results",
    input = {
      chain_results = {},
    },
    expected = {
      flattened = {},
    },
  },
  {
    id = 3982,
    type = "fk_graph",
    name = "Flatten 1-hop only",
    input = {
      chain_results = {
        {
          { target_table = "Customers", hop_count = 1 },
          { target_table = "Products", hop_count = 1 },
        },
        {},
        {},
      },
    },
    expected = {
      flattened = {
        { target_table = "Customers", hop_count = 1 },
        { target_table = "Products", hop_count = 1 },
      },
    },
  },
  {
    id = 3983,
    type = "fk_graph",
    name = "Flatten 2-hop only",
    input = {
      chain_results = {
        {},
        {
          { target_table = "Countries", hop_count = 2 },
          { target_table = "Categories", hop_count = 2 },
        },
        {},
      },
    },
    expected = {
      flattened = {
        { target_table = "Countries", hop_count = 2 },
        { target_table = "Categories", hop_count = 2 },
      },
    },
  },
  {
    id = 3984,
    type = "fk_graph",
    name = "Flatten mixed hops",
    input = {
      chain_results = {
        {
          { target_table = "Customers", hop_count = 1 },
        },
        {
          { target_table = "Countries", hop_count = 2 },
        },
        {
          { target_table = "Regions", hop_count = 3 },
        },
      },
    },
    expected = {
      flattened = {
        { target_table = "Customers", hop_count = 1 },
        { target_table = "Countries", hop_count = 2 },
        { target_table = "Regions", hop_count = 3 },
      },
    },
  },
  {
    id = 3985,
    type = "fk_graph",
    name = "Sort by hop count",
    input = {
      chain_results = {
        {
          { target_table = "Customers", hop_count = 1 },
          { target_table = "Products", hop_count = 1 },
        },
        {
          { target_table = "Countries", hop_count = 2 },
        },
        {},
      },
    },
    expected = {
      flattened = {
        { target_table = "Customers", hop_count = 1 },
        { target_table = "Products", hop_count = 1 },
        { target_table = "Countries", hop_count = 2 },
      },
      sorted_by_hop = true,
    },
  },
  {
    id = 3986,
    type = "fk_graph",
    name = "Sort stability within hop",
    input = {
      chain_results = {
        {
          { target_table = "A", hop_count = 1 },
          { target_table = "B", hop_count = 1 },
          { target_table = "C", hop_count = 1 },
        },
        {},
        {},
      },
    },
    expected = {
      flattened = {
        { target_table = "A", hop_count = 1 },
        { target_table = "B", hop_count = 1 },
        { target_table = "C", hop_count = 1 },
      },
      order_preserved = true,
    },
  },
  {
    id = 3987,
    type = "fk_graph",
    name = "Large result set",
    input = {
      chain_results = {
        {
          { target_table = "T1", hop_count = 1 },
          { target_table = "T2", hop_count = 1 },
          { target_table = "T3", hop_count = 1 },
          { target_table = "T4", hop_count = 1 },
          { target_table = "T5", hop_count = 1 },
        },
        {
          { target_table = "T6", hop_count = 2 },
          { target_table = "T7", hop_count = 2 },
          { target_table = "T8", hop_count = 2 },
        },
        {
          { target_table = "T9", hop_count = 3 },
          { target_table = "T10", hop_count = 3 },
        },
      },
    },
    expected = {
      flattened = {
        { target_table = "T1", hop_count = 1 },
        { target_table = "T2", hop_count = 1 },
        { target_table = "T3", hop_count = 1 },
        { target_table = "T4", hop_count = 1 },
        { target_table = "T5", hop_count = 1 },
        { target_table = "T6", hop_count = 2 },
        { target_table = "T7", hop_count = 2 },
        { target_table = "T8", hop_count = 2 },
        { target_table = "T9", hop_count = 3 },
        { target_table = "T10", hop_count = 3 },
      },
      count = 10,
    },
  },
  {
    id = 3988,
    type = "fk_graph",
    name = "All hops empty",
    input = {
      chain_results = {
        {},
        {},
        {},
      },
    },
    expected = {
      flattened = {},
    },
  },
  {
    id = 3989,
    type = "fk_graph",
    name = "Gaps in hop counts",
    input = {
      chain_results = {
        {
          { target_table = "A", hop_count = 1 },
        },
        {},
        {
          { target_table = "C", hop_count = 3 },
        },
      },
    },
    expected = {
      flattened = {
        { target_table = "A", hop_count = 1 },
        { target_table = "C", hop_count = 3 },
      },
    },
  },
  {
    id = 3990,
    type = "fk_graph",
    name = "Max 3 hops flattened",
    input = {
      chain_results = {
        {
          { target_table = "A", hop_count = 1 },
        },
        {
          { target_table = "B", hop_count = 2 },
        },
        {
          { target_table = "C", hop_count = 3 },
        },
      },
    },
    expected = {
      flattened = {
        { target_table = "A", hop_count = 1 },
        { target_table = "B", hop_count = 2 },
        { target_table = "C", hop_count = 3 },
      },
      max_hops = 3,
    },
  },
  {
    id = 3991,
    type = "fk_graph",
    name = "Nil results handling",
    input = {
      chain_results = nil,
    },
    expected = {
      flattened = {},
    },
  },
  {
    id = 3992,
    type = "fk_graph",
    name = "Partial results",
    input = {
      chain_results = {
        {
          { target_table = "A", hop_count = 1 },
        },
      },
    },
    expected = {
      flattened = {
        { target_table = "A", hop_count = 1 },
      },
    },
  },
  {
    id = 3993,
    type = "fk_graph",
    name = "Order preservation within hops",
    input = {
      chain_results = {
        {
          { target_table = "Z", hop_count = 1 },
          { target_table = "A", hop_count = 1 },
          { target_table = "M", hop_count = 1 },
        },
        {},
        {},
      },
    },
    expected = {
      flattened = {
        { target_table = "Z", hop_count = 1 },
        { target_table = "A", hop_count = 1 },
        { target_table = "M", hop_count = 1 },
      },
      alphabetical = false,
    },
  },
  {
    id = 3994,
    type = "fk_graph",
    name = "Duplicate handling",
    input = {
      chain_results = {
        {
          { target_table = "A", hop_count = 1 },
          { target_table = "A", hop_count = 1 },
        },
        {},
        {},
      },
    },
    expected = {
      flattened = {
        { target_table = "A", hop_count = 1 },
        { target_table = "A", hop_count = 1 },
      },
      duplicates_allowed = true,
    },
  },
  {
    id = 3995,
    type = "fk_graph",
    name = "Result integrity",
    input = {
      chain_results = {
        {
          { target_table = "A", hop_count = 1, path = {}, from_column = "AID" },
        },
        {
          { target_table = "B", hop_count = 2, path = { "A" }, from_column = "BID" },
        },
        {},
      },
    },
    expected = {
      flattened = {
        { target_table = "A", hop_count = 1, path = {}, from_column = "AID" },
        { target_table = "B", hop_count = 2, path = { "A" }, from_column = "BID" },
      },
      fields_preserved = true,
    },
  },
  {
    id = 3996,
    type = "fk_graph",
    name = "Performance with many results",
    input = {
      chain_results = {
        {
          { target_table = "T01", hop_count = 1 },
          { target_table = "T02", hop_count = 1 },
          { target_table = "T03", hop_count = 1 },
          { target_table = "T04", hop_count = 1 },
          { target_table = "T05", hop_count = 1 },
          { target_table = "T06", hop_count = 1 },
          { target_table = "T07", hop_count = 1 },
          { target_table = "T08", hop_count = 1 },
          { target_table = "T09", hop_count = 1 },
          { target_table = "T10", hop_count = 1 },
        },
        {
          { target_table = "T11", hop_count = 2 },
          { target_table = "T12", hop_count = 2 },
          { target_table = "T13", hop_count = 2 },
          { target_table = "T14", hop_count = 2 },
          { target_table = "T15", hop_count = 2 },
        },
        {
          { target_table = "T16", hop_count = 3 },
          { target_table = "T17", hop_count = 3 },
        },
      },
    },
    expected = {
      flattened = {
        { target_table = "T01", hop_count = 1 },
        { target_table = "T02", hop_count = 1 },
        { target_table = "T03", hop_count = 1 },
        { target_table = "T04", hop_count = 1 },
        { target_table = "T05", hop_count = 1 },
        { target_table = "T06", hop_count = 1 },
        { target_table = "T07", hop_count = 1 },
        { target_table = "T08", hop_count = 1 },
        { target_table = "T09", hop_count = 1 },
        { target_table = "T10", hop_count = 1 },
        { target_table = "T11", hop_count = 2 },
        { target_table = "T12", hop_count = 2 },
        { target_table = "T13", hop_count = 2 },
        { target_table = "T14", hop_count = 2 },
        { target_table = "T15", hop_count = 2 },
        { target_table = "T16", hop_count = 3 },
        { target_table = "T17", hop_count = 3 },
      },
      count = 17,
    },
  },
  {
    id = 3997,
    type = "fk_graph",
    name = "Single result per hop",
    input = {
      chain_results = {
        {
          { target_table = "A", hop_count = 1 },
        },
        {
          { target_table = "B", hop_count = 2 },
        },
        {
          { target_table = "C", hop_count = 3 },
        },
      },
    },
    expected = {
      flattened = {
        { target_table = "A", hop_count = 1 },
        { target_table = "B", hop_count = 2 },
        { target_table = "C", hop_count = 3 },
      },
      count = 3,
    },
  },
  {
    id = 3998,
    type = "fk_graph",
    name = "Empty arrays at each hop",
    input = {
      chain_results = {
        {},
        {},
        {},
      },
    },
    expected = {
      flattened = {},
      count = 0,
    },
  },
  {
    id = 3999,
    type = "fk_graph",
    name = "Flatten with extra metadata",
    input = {
      chain_results = {
        {
          { target_table = "A", hop_count = 1, constraint_name = "FK_A", from_column = "AID" },
        },
        {
          { target_table = "B", hop_count = 2, constraint_name = "FK_B", from_column = "BID", path = { "A" } },
        },
        {},
      },
    },
    expected = {
      flattened = {
        { target_table = "A", hop_count = 1, constraint_name = "FK_A", from_column = "AID" },
        { target_table = "B", hop_count = 2, constraint_name = "FK_B", from_column = "BID", path = { "A" } },
      },
      metadata_preserved = true,
    },
  },
  {
    id = 4000,
    type = "fk_graph",
    name = "Flatten with nested data",
    input = {
      chain_results = {
        {
          { target_table = "Orders", hop_count = 1, fk_info = { from = "CustomerID", to = "CustomerID" } },
        },
        {
          { target_table = "Countries", hop_count = 2, path = { "Customers" }, fk_info = { from = "CountryID", to = "CountryID" } },
        },
        {},
      },
    },
    expected = {
      flattened = {
        { target_table = "Orders", hop_count = 1, fk_info = { from = "CustomerID", to = "CustomerID" } },
        { target_table = "Countries", hop_count = 2, path = { "Customers" }, fk_info = { from = "CountryID", to = "CountryID" } },
      },
      nested_preserved = true,
    },
  },
}
