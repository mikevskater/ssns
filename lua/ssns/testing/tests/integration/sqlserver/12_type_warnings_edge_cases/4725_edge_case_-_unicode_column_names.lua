-- Test 4725: Edge case - Unicode column names

return {
  number = 4725,
  description = "Edge case - Unicode column names",
  database = "vim_dadbod_test",
  query = "SELECT [名前], [住所] F█ROM JapaneseTable",
  expected = {
    items = {
      includes_any = {
        "名前",
        "住所",
      },
    },
    type = "column",
  },
}
