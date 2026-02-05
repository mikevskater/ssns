-- Test 4547: Subquery - subquery in UNPIVOT source

return {
  number = 4547,
  description = "Subquery - subquery in UNPIVOT source",
  database = "vim_dadbod_test",
  query = [[SELECT * FROM (SELECT █ FROM Orders) src
UNPIVOT (Value FOR Quarter IN (OrderId, CustomerId, Total)) unpvt]],
  expected = {
    items = {
      includes_any = {
        "OrderId",
        "CustomerId",
        "Total",
      },
    },
    type = "column",
  },
}
