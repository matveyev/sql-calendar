WITH param(year, c, r) AS (
  SELECT 2016, 3, 4
),
mon_nums AS (
  SELECT generate_series(1, 12) AS mon_num -- генерируем номера месяцев
),
mon_info AS ( -- для каждого месяца определяем количество дней, день недели первого дня и название
  SELECT 
    mon_num,
    DATE_PART('isodow', CONCAT((SELECT year FROM param), '-', mon_num, '-', 1)::DATE) :: INT - 1 as pos,
    DATE_PART('day', CONCAT((SELECT year FROM param), '-', mon_num, '-', 1)::DATE + '1 MONTH':: INTERVAL - '1 DAY' :: INTERVAL) :: INT as day_count,
    TO_CHAR(CONCAT((SELECT year FROM param), '-', mon_num, '-', 1)::DATE, 'FMMonth') as name
  FROM 
    mon_nums
),
mon_days AS (
  SELECT 
    mon_num, 
    generate_series(1, mon_info.day_count) as day -- генерируем дни для каждого месяца
  FROM 
    mon_info
),
cell_positions AS ( -- рассчитаем позиции ячеек в календарной сетке
  SELECT 
    mi.mon_num, -- номер месяца
    LPAD(md.day :: TEXT, 4, ' ') as day_str, -- текст в сетке всегда фиксированной длины в 4 символа
    FLOOR((md.day + mi.pos - 1) / 7.0) as y, -- позиция по горизонтали
    (md.day + mi.pos - 1) :: INT % 7 as x -- позиция по вертикали
  FROM 
    mon_info mi
  INNER JOIN 
    mon_days md on md.mon_num = mi.mon_num
),
dummy_cells AS ( -- нужно сгенерить пустые ячейки, чтобы они занимали место там, где нет ячеек с днями
  SELECT 
    mon_num, 
    '    ' :: TEXT as day_str, -- всегда 4 символа
    generate_series(0, 5) as y, -- 6 строк в сетке 
    xs.x
  FROM 
    mon_nums
  CROSS JOIN 
    (
      SELECT generate_series(0, 6) as x -- по 7 дней
    ) xs
),
full_cells AS ( -- совмещенные пустые и не пустые ячейки
  SELECT 
    dc.mon_num, 
    COALESCE(rc.day_str, dc.day_str) as day_str, -- если есть, берем реальный день, иначе значение пустой ячейки
    dc.y, 
    dc.x 
  FROM 
    dummy_cells dc 
  LEFT JOIN 
    cell_positions rc ON rc.mon_num = dc.mon_num AND rc.y = dc.y AND rc.x = dc.x
),
cal_rows AS ( -- строки календаря
  SELECT 
    mon_num, 
    y, -- вертикальная координата
    array_to_string(array_agg(day_str), '') as cal_row -- строка по этой координате для данного месяца
  FROM 
    full_cells
  GROUP BY 
    mon_num, y -- группируем по вертикали
  ORDER BY 
    mon_num, y
),
calendars AS ( -- полноценные календари по месяцам
  SELECT 
    cr.mon_num, 
    array_cat( -- календарь пока это массив строк
      ARRAY[LPAD(CONCAT(mn.name, REPEAT(' ', 4 * 7 / 2 - CHAR_LENGTH(mn.name) / 2)), 4 * 7, ' ')], -- помещаем в начало массива название месяца и выравниваем по центру
      array_agg(cal_row) -- сами строки календаря
    ) AS c_rows
  FROM 
    cal_rows cr
  INNER JOIN 
    mon_info mn ON cr.mon_num = mn.mon_num
  GROUP BY 
    cr.mon_num, mn.name
),
str_rows AS ( -- таблица с пронумерованными текстовыми строками календарей и с привязкой к месяцу
  SELECT 
    mon_num, 
    UNNEST(c_rows) as r_text, -- unnest здесь породит для каждого mon_num столько строк, сколько элементов в массиве (а их всегда 6 + 1 на название месяца)
    generate_subscripts(c_rows, 1) as row_idx -- эта колонка будет содержать индексы этих элементов (если сейчас сгруппируем по этому полю и отсортируем, получим 7 строк, на которых в ряд будут выстроены все календари)
  FROM 
    calendars 
  ORDER BY 
    mon_num, row_idx
),
mon_bounds AS ( -- границы месяцев, в зависимости от входных параметров
  SELECT
    ser.row_num * (SELECT c FROM param) AS mon_gt, -- начало диапазона месяцев
    (ser.row_num + 1) * (SELECT c FROM param) AS mon_lte -- конец диапазона месяцев
  FROM
    (
      SELECT 
        generate_series(0, (SELECT r - 1 FROM param)) AS row_num -- сгенерим столько строк, сколько у казано в параметре
    ) AS ser
)
SELECT -- выведем отцентрированное значение года
  LPAD(
    CONCAT(
      (SELECT year FROM param) :: TEXT, 
      REPEAT(
        ' ', ( 4 * 7 * (SELECT c FROM param) + 4 * (SELECT c - 1 FROM param) ) / 2 - 4 / 2
      )
    ), 
    4 * 7 * (SELECT c FROM param) + 4 * (SELECT c - 1 FROM param), ' '
  ) :: TEXT
UNION ALL
SELECT -- пройдемся по таблице с диапазонами месяцев и для каждой строки найдем каледнари, попадающие в диапазон
  UNNEST(
    ARRAY(
      SELECT 
        array_to_string(array_agg(r_text), '    ') -- соединим каледнари 4 пробелами по горизонтали
      FROM 
        str_rows
      WHERE 
        mon_num > b.mon_gt AND mon_num <= b.mon_lte -- поскольку в str_rows все календари выстроены в ряд, выбираем только те, которые должны попасть на данную строку (календари будут играть роль столбцов)
      GROUP BY 
        row_idx -- группируем по номеру строки чтобы все календари встали в ряд
      ORDER BY 
        row_idx
    )
  ) as calendar
FROM 
  mon_bounds b;