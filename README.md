# SQL Olympiad Calendar Task Solution

## Problem Statement

Write a single SQL query that generates a pocket calendar. The task parameters are the calendar year and the number of rows and columns used to lay the months out as a matrix. The parameters are provided by the following query:

```sql
with param(year, c, r) (…)
```

where, respectively:

* year – the calendar year
* c – the number of columns in the calendar matrix
* r – the number of matrix rows.

The months are placed in the cells of the calendar matrix in order, left to right and then top to bottom. Within each month, the day numbers are arranged by day of week, with the first day of the week in the first column, and so on. The first day of the week must match the database's localization settings at the moment the query runs. The month name is also taken from the localization settings and is printed centered above the day numbers. A gap must be left between the months so that the numbers of adjacent months do not stick together. The very first line must be the year, centered. There must be no empty lines.

For example, given the following parameters:

```sql
with param(year, c, r) as (select 2016, 3, 4 from dual)
```

the query must produce the following output:

```
                                  2016
        January                 February                 March
              1  2  3     1  2  3  4  5  6  7        1  2  3  4  5  6
  4  5  6  7  8  9 10     8  9 10 11 12 13 14     7  8  9 10 11 12 13
 11 12 13 14 15 16 17    15 16 17 18 19 20 21    14 15 16 17 18 19 20
 18 19 20 21 22 23 24    22 23 24 25 26 27 28    21 22 23 24 25 26 27
 25 26 27 28 29 30 31    29                      28 29 30 31
         April                    May                     June
              1  2  3                       1           1  2  3  4  5
  4  5  6  7  8  9 10     2  3  4  5  6  7  8     6  7  8  9 10 11 12
 11 12 13 14 15 16 17     9 10 11 12 13 14 15    13 14 15 16 17 18 19
 18 19 20 21 22 23 24    16 17 18 19 20 21 22    20 21 22 23 24 25 26
 25 26 27 28 29 30       23 24 25 26 27 28 29    27 28 29 30
                         30 31
          July                   August                September
              1  2  3     1  2  3  4  5  6  7              1  2  3  4
  4  5  6  7  8  9 10     8  9 10 11 12 13 14     5  6  7  8  9 10 11
 11 12 13 14 15 16 17    15 16 17 18 19 20 21    12 13 14 15 16 17 18
 18 19 20 21 22 23 24    22 23 24 25 26 27 28    19 20 21 22 23 24 25
 25 26 27 28 29 30 31    29 30 31                26 27 28 29 30
        October                 November                December
                 1  2        1  2  3  4  5  6              1  2  3  4
  3  4  5  6  7  8  9     7  8  9 10 11 12 13     5  6  7  8  9 10 11
 10 11 12 13 14 15 16    14 15 16 17 18 19 20    12 13 14 15 16 17 18
 17 18 19 20 21 22 23    21 22 23 24 25 26 27    19 20 21 22 23 24 25
 24 25 26 27 28 29 30    28 29 30                26 27 28 29 30 31
 31
```

## Running the Solution in Docker

The solution has been tested on PostgreSQL 18. Month names are taken from the database's localization settings (`lc_time`); with the image's default locale they come out in English. Note that the project directory is mounted rather than the single file — when an editor replaces the file, a single-file mount keeps serving the old version:

```
docker run -d --name test_postgres \
  -e POSTGRES_HOST_AUTH_METHOD=trust \
  -v "$PWD:/work:ro" \
  postgres:18
```

`POSTGRES_HOST_AUTH_METHOD=trust` disables authentication, which is convenient for local experiments; otherwise set `POSTGRES_PASSWORD` instead.

Wait until the server is ready and run the script (the `-t -A` flags disable psql's tabular output so that the calendar is printed as plain text):

```
until docker exec test_postgres pg_isready -U postgres -q; do sleep 1; done
docker exec test_postgres psql -U postgres -tAf /work/calendar.sql
```

When finished, remove the container:

```
docker rm -f test_postgres
```

## Solution Notes

* `to_char(..., 'FMMonth')` does not localize month names — the `TM` prefix is required for that: `to_char(..., 'TMMonth')` takes the names from `lc_time`.
* The order of the days within a week is pinned down by ordering inside the aggregates (`ORDER BY` in `string_agg` and `array_agg`) — without it, on modern PostgreSQL versions (hash aggregation) the days get shuffled within a calendar line.
* Week rows that are empty for every month of a matrix band are filtered out (`WHERE trim(calendar) <> ''`) — the problem statement requires that there be no empty lines.
* The order of the result rows is guaranteed by a final `ORDER BY` over an auxiliary row number, not by whatever order the query plan happens to produce.
