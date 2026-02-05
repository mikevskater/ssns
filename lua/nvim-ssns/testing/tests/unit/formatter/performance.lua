-- Performance tests for the SQL formatter
-- Test IDs: 8301-8350
-- These tests verify formatting speed and caching behavior

return {
  -- ============================================
  -- Basic Performance Tests (8301-8310)
  -- ============================================

  {
    id = 8301,
    type = "formatter",
    name = "format_simple_select_under_10ms",
    description = "Simple SELECT should format in under 10ms",
    input = "select id, name, email from users where active = 1",
    expected = {
      -- Using contains to verify it formats, timing is checked by the runner
      contains = { "SELECT", "FROM", "WHERE" },
      max_duration_ms = 10,
    },
  },

  {
    id = 8302,
    type = "formatter",
    name = "format_medium_query_under_20ms",
    description = "Medium complexity query should format in under 20ms",
    input = [[
      select u.id, u.name, u.email, o.order_date, o.total
      from users u
      inner join orders o on u.id = o.user_id
      left join payments p on o.id = p.order_id
      where u.status = 'active' and o.total > 100
      order by o.order_date desc
    ]],
    expected = {
      contains = { "SELECT", "FROM", "INNER JOIN", "LEFT JOIN", "WHERE", "ORDER BY" },
      max_duration_ms = 20,
    },
  },

  {
    id = 8303,
    type = "formatter",
    name = "format_cte_query_under_25ms",
    description = "CTE query should format in under 25ms",
    input = [[
      with recent_orders as (
        select user_id, count(*) as order_count, sum(total) as total_spent
        from orders
        where order_date > dateadd(month, -3, getdate())
        group by user_id
      ),
      vip_users as (
        select user_id from recent_orders where total_spent > 1000
      )
      select u.name, ro.order_count, ro.total_spent
      from users u
      inner join recent_orders ro on u.id = ro.user_id
      where u.id in (select user_id from vip_users)
    ]],
    expected = {
      contains = { "WITH", "SELECT", "FROM", "WHERE", "GROUP BY" },
      max_duration_ms = 25,
    },
  },

  {
    id = 8304,
    type = "formatter",
    name = "format_window_functions_under_20ms",
    description = "Window functions should format in under 20ms",
    input = [[
      select employee_id, department, salary,
        row_number() over (partition by department order by salary desc) as rank,
        sum(salary) over (partition by department) as dept_total,
        avg(salary) over () as company_avg
      from employees
    ]],
    expected = {
      contains = { "SELECT", "ROW_NUMBER", "OVER", "PARTITION BY", "ORDER BY" },
      max_duration_ms = 20,
    },
  },

  {
    id = 8305,
    type = "formatter",
    name = "format_case_expressions_under_15ms",
    description = "CASE expressions should format in under 15ms",
    input = [[
      select id, name,
        case status
          when 1 then 'Active'
          when 2 then 'Pending'
          when 3 then 'Inactive'
          else 'Unknown'
        end as status_text,
        case when score > 90 then 'A' when score > 80 then 'B' else 'C' end as grade
      from items
    ]],
    expected = {
      contains = { "SELECT", "CASE", "WHEN", "THEN", "ELSE", "END" },
      max_duration_ms = 15,
    },
  },

  -- ============================================
  -- Large Input Performance Tests (8311-8320)
  -- ============================================

  {
    id = 8311,
    type = "formatter",
    name = "format_20_column_select_under_20ms",
    description = "SELECT with 20 columns should format in under 20ms",
    input = "select col1, col2, col3, col4, col5, col6, col7, col8, col9, col10, " ..
            "col11, col12, col13, col14, col15, col16, col17, col18, col19, col20 " ..
            "from large_table where active = 1",
    expected = {
      contains = { "SELECT", "col1", "col20", "FROM", "WHERE" },
      max_duration_ms = 20,
    },
  },

  {
    id = 8312,
    type = "formatter",
    name = "format_10_join_query_under_30ms",
    description = "Query with 10 JOINs should format in under 30ms",
    input = [[
      select t.id from main_table t
      inner join table1 t1 on t.id = t1.main_id
      inner join table2 t2 on t.id = t2.main_id
      left join table3 t3 on t.id = t3.main_id
      left join table4 t4 on t.id = t4.main_id
      inner join table5 t5 on t.id = t5.main_id
      inner join table6 t6 on t.id = t6.main_id
      left join table7 t7 on t.id = t7.main_id
      left join table8 t8 on t.id = t8.main_id
      inner join table9 t9 on t.id = t9.main_id
      inner join table10 t10 on t.id = t10.main_id
    ]],
    expected = {
      contains = { "SELECT", "FROM", "INNER JOIN", "LEFT JOIN", "ON" },
      max_duration_ms = 30,
    },
  },

  {
    id = 8313,
    type = "formatter",
    name = "format_15_where_conditions_under_25ms",
    description = "Query with 15 WHERE conditions should format in under 25ms",
    input = [[
      select * from test_table
      where col1 = 1 and col2 = 2 and col3 = 3 and col4 = 4 and col5 = 5
      and col6 in (1, 2, 3) and col7 between 10 and 20
      and col8 like '%test%' and col9 is not null
      and col10 > 100 and col11 < 50
      and col12 <> 'x' and col13 >= 0 and col14 <= 999
      and col15 = (select max(id) from other_table)
    ]],
    expected = {
      contains = { "SELECT", "FROM", "WHERE", "AND", "IN", "BETWEEN", "LIKE", "IS NOT NULL" },
      max_duration_ms = 25,
    },
  },

  {
    id = 8314,
    type = "formatter",
    name = "format_nested_subqueries_under_30ms",
    description = "Nested subqueries (4 levels) should format in under 30ms",
    input = [[
      select * from (
        select * from (
          select * from (
            select * from (
              select id, name from base_table
            ) level4
          ) level3
        ) level2
      ) level1
    ]],
    expected = {
      contains = { "SELECT", "FROM", "level1", "level2", "level3", "level4" },
      max_duration_ms = 30,
    },
  },

  {
    id = 8315,
    type = "formatter",
    name = "format_5_cte_query_under_35ms",
    description = "Query with 5 CTEs should format in under 35ms",
    input = [[
      with cte1 as (select id, val from t1),
      cte2 as (select id, val from t2),
      cte3 as (select id, val from t3),
      cte4 as (select id, val from t4),
      cte5 as (select id, val from t5)
      select c1.id, c2.val, c3.val, c4.val, c5.val
      from cte1 c1
      join cte2 c2 on c1.id = c2.id
      join cte3 c3 on c1.id = c3.id
      join cte4 c4 on c1.id = c4.id
      join cte5 c5 on c1.id = c5.id
    ]],
    expected = {
      contains = { "WITH", "cte1", "cte2", "cte3", "cte4", "cte5", "SELECT", "FROM", "JOIN" },
      max_duration_ms = 35,
    },
  },

  -- ============================================
  -- Caching Tests (8321-8330)
  -- ============================================

  {
    id = 8321,
    type = "formatter",
    name = "cache_hit_faster_than_cold",
    description = "Second format call should be faster due to caching",
    input = "select id, name from users where active = 1",
    expected = {
      contains = { "SELECT", "FROM", "WHERE" },
      -- This test verifies caching works - second call uses cached tokens
      cache_test = true,
    },
  },

  {
    id = 8322,
    type = "formatter",
    name = "different_queries_no_false_cache_hit",
    description = "Different queries should not share cache entries",
    input = "select a from table1",
    expected = {
      contains = { "SELECT", "FROM" },
    },
    -- The runner should verify this query produces different output than "select b from table2"
  },

  -- ============================================
  -- Batch/Multiple Statement Tests (8331-8340)
  -- ============================================

  {
    id = 8331,
    type = "formatter",
    name = "format_5_statements_under_40ms",
    description = "5 sequential statements should format in under 40ms",
    input = [[
      select * from t1;
      select * from t2;
      select * from t3;
      select * from t4;
      select * from t5;
    ]],
    expected = {
      contains = { "SELECT", "FROM", "t1", "t2", "t3", "t4", "t5" },
      max_duration_ms = 40,
    },
  },

  {
    id = 8332,
    type = "formatter",
    name = "format_dml_batch_under_30ms",
    description = "Mixed DML batch should format in under 30ms",
    input = [[
      insert into audit_log (action) values ('start');
      update users set last_login = getdate() where id = 1;
      delete from temp_data where created < dateadd(day, -1, getdate());
      select count(*) from audit_log;
    ]],
    expected = {
      contains = { "INSERT", "UPDATE", "DELETE", "SELECT" },
      max_duration_ms = 30,
    },
  },

  {
    id = 8333,
    type = "formatter",
    name = "format_go_separated_batch_under_35ms",
    description = "GO-separated batch should format in under 35ms",
    input = [[
      select * from table1
      go
      select * from table2
      go
      select * from table3
    ]],
    expected = {
      contains = { "SELECT", "FROM", "GO" },
      max_duration_ms = 35,
    },
  },

  -- ============================================
  -- Stress Tests (8341-8350)
  -- ============================================

  {
    id = 8341,
    type = "formatter",
    name = "format_1000_char_query_under_50ms",
    description = "1000+ character query should format in under 50ms",
    input = "select " .. string.rep("col, ", 100) .. "final_col from very_long_table " ..
            "where " .. string.rep("cond = 1 and ", 30) .. "final_cond = 1",
    expected = {
      contains = { "SELECT", "FROM", "WHERE" },
      max_duration_ms = 50,
    },
  },

  {
    id = 8342,
    type = "formatter",
    name = "format_deep_expression_under_30ms",
    description = "Deeply nested expressions should format in under 30ms",
    input = "select (((((a + b) * c) - d) / e) + f) as calc_result from calc_table",
    expected = {
      -- Use calc_result instead of result to avoid keyword confusion
      contains = { "SELECT", "FROM", "calc_result" },
      max_duration_ms = 30,
    },
  },

  {
    id = 8343,
    type = "formatter",
    name = "format_many_in_values_under_25ms",
    description = "IN clause with many values should format in under 25ms",
    input = "select * from items where id in (1, 2, 3, 4, 5, 6, 7, 8, 9, 10, " ..
            "11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25)",
    expected = {
      contains = { "SELECT", "FROM", "WHERE", "IN" },
      max_duration_ms = 25,
    },
  },

  {
    id = 8344,
    type = "formatter",
    name = "format_complex_production_query_under_60ms",
    description = "Complex production-style query should format in under 60ms",
    input = [[
      with monthly_sales as (
        select
          year(order_date) as order_year,
          month(order_date) as order_month,
          customer_id,
          sum(total_amount) as monthly_total,
          count(*) as order_count
        from orders o
        inner join order_items oi on o.id = oi.order_id
        where o.status = 'completed'
          and o.order_date >= dateadd(year, -1, getdate())
        group by year(order_date), month(order_date), customer_id
      ),
      customer_rankings as (
        select
          customer_id,
          order_year,
          order_month,
          monthly_total,
          row_number() over (partition by order_year, order_month order by monthly_total desc) as rank
        from monthly_sales
      )
      select
        c.name as customer_name,
        cr.order_year,
        cr.order_month,
        cr.monthly_total,
        cr.rank,
        case when cr.rank <= 10 then 'Top 10' when cr.rank <= 50 then 'Top 50' else 'Other' end as tier
      from customer_rankings cr
      inner join customers c on cr.customer_id = c.id
      where cr.rank <= 100
      order by cr.order_year desc, cr.order_month desc, cr.rank
    ]],
    expected = {
      contains = { "WITH", "SELECT", "FROM", "INNER JOIN", "WHERE", "GROUP BY", "ORDER BY", "ROW_NUMBER", "OVER", "CASE" },
      max_duration_ms = 60,
    },
  },

  {
    id = 8345,
    type = "formatter",
    name = "format_empty_input_instant",
    description = "Empty input should return instantly",
    input = "",
    expected = {
      formatted = "",
      max_duration_ms = 1,
    },
  },

  {
    id = 8346,
    type = "formatter",
    name = "format_whitespace_only_fast",
    description = "Whitespace-only input should handle quickly",
    input = "   \n\t  \n   ",
    expected = {
      max_duration_ms = 5,
    },
  },

  {
    id = 8347,
    type = "formatter",
    name = "format_single_keyword_fast",
    description = "Single keyword should format instantly",
    input = "SELECT",
    expected = {
      contains = { "SELECT" },
      max_duration_ms = 5,
    },
  },

  {
    id = 8348,
    type = "formatter",
    name = "format_comments_only_fast",
    description = "Comment-only input should handle quickly",
    input = "-- This is a comment\n/* Block comment */",
    expected = {
      contains = { "--", "/*", "*/" },
      max_duration_ms = 10,
    },
  },

  {
    id = 8349,
    type = "formatter",
    name = "format_unicode_identifiers_under_15ms",
    description = "Unicode identifiers should format correctly and quickly",
    input = "select [Имя], [名前], [שם] from [Таблица] where [Колонка] = 'значение'",
    expected = {
      contains = { "SELECT", "FROM", "WHERE" },
      max_duration_ms = 15,
    },
  },

  {
    id = 8350,
    type = "formatter",
    name = "format_mixed_case_keywords_under_10ms",
    description = "Mixed case keywords should normalize quickly",
    input = "SeLeCt Id, NaMe FrOm UsErS wHeRe AcTiVe = 1",
    expected = {
      contains = { "SELECT", "FROM", "WHERE" },
      not_contains = { "SeLeCt", "FrOm", "wHeRe" },
      max_duration_ms = 10,
    },
  },
}
