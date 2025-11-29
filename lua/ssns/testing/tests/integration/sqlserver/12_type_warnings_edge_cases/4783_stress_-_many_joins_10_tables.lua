-- Test 4783: Stress - many JOINs (10 tables)

return {
  number = 4783,
  description = "Stress - many JOINs (10 tables)",
  database = "vim_dadbod_test",
  query = "SELECT * FROM T1 JOIN T2 ON T1.ID = T2.ID JOIN T3 ON T2.ID = T3.ID JOIN T4 ON T3.ID = T4.ID JOIN T5 ON T4.ID = T5.ID JOIN T6 ON T5.ID = T6.ID JOIN T7 ON T6.ID = T7.ID JOIN T8 ON T7.ID = T8.ID JOIN T9 ON T8.ID = T9.ID JOIN T10 ON T9.ID = T10█.",
  expected = {
    items = {
      includes = {
        "ID",
      },
    },
    type = "column",
  },
}
