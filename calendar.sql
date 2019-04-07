-- Pocket calendar (SQL Olympiad task).
-- Parameters: year — the calendar year, c — the number of columns, r — the number of rows in the month matrix.
-- The week layout (ISO, Monday first) and month names are taken from the
-- database localization settings (lc_time). Tested on PostgreSQL 18.
WITH param(year, c, r) AS (
  SELECT 2016, 3, 4
),
mon_info AS ( -- for each month: weekday of the first day, number of days, name
  SELECT
    m.mon_num,
    extract(isodow FROM make_date(p.year, m.mon_num, 1))::int - 1 AS pos, -- 0 = first day of the week
    extract(day FROM make_date(p.year, m.mon_num, 1) + interval '1 month' - interval '1 day')::int AS day_count,
    to_char(make_date(p.year, m.mon_num, 1), 'TMMonth') AS name -- localized month name
  FROM param p
  CROSS JOIN generate_series(1, 12) AS m(mon_num) -- generate the month numbers
),
mon_days AS ( -- days of the month and their grid positions: x — column (weekday), y — row (week)
  SELECT
    mi.mon_num,
    lpad(d.day::text, 3) AS day_str, -- a day cell is always 3 characters wide
    (d.day + mi.pos - 1) / 7 AS y,
    (d.day + mi.pos - 1) % 7 AS x
  FROM mon_info mi
  CROSS JOIN generate_series(1, mi.day_count) AS d(day)
),
dummy_cells AS ( -- empty cells where the grid has no days
  SELECT m.mon_num, '   '::text AS day_str, ys.y, xs.x
  FROM generate_series(1, 12) AS m(mon_num)
  CROSS JOIN generate_series(0, 5) AS ys(y) -- at most 6 weeks per month
  CROSS JOIN generate_series(0, 6) AS xs(x) -- 7 days per week
),
full_cells AS ( -- combined empty and real cells
  SELECT dc.mon_num, dc.y, dc.x, coalesce(md.day_str, dc.day_str) AS day_str
  FROM dummy_cells dc
  LEFT JOIN mon_days md ON md.mon_num = dc.mon_num AND md.y = dc.y AND md.x = dc.x
),
cal_rows AS ( -- week rows of a month, 7 * 3 = 21 characters wide
  SELECT mon_num, y, string_agg(day_str, '' ORDER BY x) AS cal_row
  FROM full_cells
  GROUP BY mon_num, y
),
calendars AS ( -- a month calendar — an array of rows: centered name + 6 weeks
  SELECT
    cr.mon_num,
    ARRAY[rpad(lpad(mn.name, (24 + char_length(mn.name)) / 2), 21)] -- month name centered within the "month + gap" slot
      || array_agg(cr.cal_row ORDER BY cr.y) AS c_rows
  FROM cal_rows cr
  JOIN mon_info mn USING (mon_num)
  GROUP BY cr.mon_num, mn.name
),
str_rows AS ( -- rows of all calendars with their numbers: 1 — the name, 2..7 — the weeks
  SELECT c.mon_num, u.ordinality AS row_idx, u.r_text
  FROM calendars c
  CROSS JOIN LATERAL unnest(c.c_rows) WITH ORDINALITY AS u(r_text, ordinality)
),
mon_bounds AS ( -- month ranges for each row of the matrix
  SELECT
    s.n AS row_num,
    s.n * (SELECT c FROM param) AS mon_gt,
    (s.n + 1) * (SELECT c FROM param) AS mon_lte
  FROM generate_series(0, (SELECT r - 1 FROM param)) AS s(n)
),
band_lines AS ( -- horizontal bands: the month calendars of a matrix row joined by 3 spaces
  SELECT
    b.row_num,
    r.row_idx,
    array_to_string(array_agg(r.r_text ORDER BY r.mon_num), '   ') AS line
  FROM mon_bounds b
  JOIN str_rows r ON r.mon_num > b.mon_gt AND r.mon_num <= b.mon_lte
  GROUP BY b.row_num, r.row_idx
)
SELECT calendar
FROM (
  SELECT
    0 AS seq, -- the first line is the year, centered across the whole grid
    rpad(lpad(p.year::text, (24 * p.c + char_length(p.year::text)) / 2), 24 * p.c) AS calendar
  FROM param p
  UNION ALL
  SELECT (row_num + 1) * 10 + row_idx, line
  FROM band_lines
) cal
WHERE trim(calendar) <> '' -- skip completely empty lines
ORDER BY seq;
