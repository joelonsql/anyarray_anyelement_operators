BEGIN;

CREATE TYPE udt AS (
udt_schema text,
udt_name text
);

CREATE TYPE sql_cmd_pairs AS (
sql1 text,
sql2 text
);

CREATE TABLE test_values (
test_value_id bigint GENERATED ALWAYS AS IDENTITY,
udt_schema text NOT NULL,
udt_name text NOT NULL,
value1 text NOT NULL,
value2 text,
PRIMARY KEY (test_value_id)
);

DO $_$
DECLARE
_value text;
_schema_name text;
_table_name text;
_column_name text;
_udt_schema text;
_udt_name text;
_udts udt[];
_found boolean;
BEGIN

SELECT array_agg(DISTINCT ROW(udt_schema, udt_name)::udt)
INTO _udts
FROM information_schema.columns
WHERE udt_name NOT IN ('anyarray','xml')
AND data_type <> 'ARRAY';

FOR _schema_name, _table_name, _column_name, _udt_schema, _udt_name IN
SELECT
  table_schema,
  table_name,
  column_name,
  udt_schema,
  udt_name
FROM information_schema.columns
WHERE udt_name NOT IN ('anyarray','xml')
AND data_type <> 'ARRAY'
ORDER BY 1,2,3,4,5
LOOP
  IF NOT ROW(_udt_schema,_udt_name)::udt = ANY(_udts) THEN
    CONTINUE;
  END IF;
  FOR _value IN
  EXECUTE format($$SELECT DISTINCT %1$I::text FROM %2$I.%3$I WHERE %1$I IS NOT NULL AND %1$I::text <> '' ORDER BY 1 LIMIT 2$$, _column_name, _schema_name, _table_name)
  LOOP
--    RAISE NOTICE '% <= %.%.%::%.%', _value, _schema_name, _table_name, _column_name, _udt_schema, _udt_name;
    IF NOT EXISTS (SELECT 1 FROM test_values WHERE udt_schema = _udt_schema AND udt_name = _udt_name) THEN
      INSERT INTO test_values (udt_schema, udt_name, value1) VALUES (_udt_schema, _udt_name, _value);
    ELSIF EXISTS (SELECT 1 FROM test_values WHERE udt_schema = _udt_schema AND udt_name = _udt_name AND value1 <> _value AND value2 IS NULL) THEN
      UPDATE test_values SET value2 = _value WHERE udt_schema = _udt_schema AND udt_name = _udt_name;
      _udts := array_remove(_udts, ROW(_udt_schema,_udt_name)::udt);
    END IF;
  END LOOP;
END LOOP;

END
$_$;

DO $$
DECLARE
_udt_schema1 text;
_udt_name1 text;
_udt_schema2 text;
_udt_name2 text;
_value1 text;
_value2 text;
_value3 text;
_error1 text;
_error2 text;
_bool1 boolean;
_bool2 boolean;
_sql1 text;
_sql2 text;
_sql_cmd_pair sql_cmd_pairs;
_failed integer := 0;
_tests integer := 0;
BEGIN

FOR
  _udt_schema1,
  _udt_name1,
  _udt_schema2,
  _udt_name2,
  _value1,
  _value2
IN
SELECT
  a.udt_schema,
  a.udt_name,
  b.udt_schema,
  b.udt_name,
  a.value1,
  b.value1
FROM
  test_values AS a
CROSS JOIN
  test_values AS b
UNION ALL
SELECT
  a.udt_schema,
  a.udt_name,
  b.udt_schema,
  b.udt_name,
  a.value1,
  b.value2
FROM
  test_values AS a
CROSS JOIN
  test_values AS b
ORDER BY 1,2,3,4,5,6
LOOP
  FOREACH _value3 IN ARRAY ARRAY[_value1,_value2] LOOP
    FOREACH _sql_cmd_pair IN ARRAY ARRAY[
      ROW(
        format('SELECT %1$L::%3$I.%4$I = ANY(ARRAY[%2$L]::%5$I.%6$I[])', _value1, _value3, _udt_schema1, _udt_name1, _udt_schema2, _udt_name2),
        format('SELECT %1$L::%3$I.%4$I <<@ ARRAY[%2$L]::%5$I.%6$I[]', _value1, _value3, _udt_schema1, _udt_name1, _udt_schema2, _udt_name2)
      )::sql_cmd_pairs,
      ROW(
        format('SELECT %1$L::%5$I.%6$I = ANY(ARRAY[%2$L]::%3$I.%4$I[])', _value1, _value3, _udt_schema1, _udt_name1, _udt_schema2, _udt_name2),
        format('SELECT ARRAY[%2$L]::%3$I.%4$I[] @>> %1$L::%5$I.%6$I', _value1, _value3, _udt_schema1, _udt_name1, _udt_schema2, _udt_name2)
      )::sql_cmd_pairs
    ] LOOP
      _bool1 := NULL;
      _bool2 := NULL;
      _error1 := NULL;
      _error2 := NULL;
      BEGIN
        EXECUTE _sql_cmd_pair.sql1
        INTO _bool1;
      EXCEPTION WHEN OTHERS THEN
        _error1 := SQLERRM;
      END;
      BEGIN
        EXECUTE _sql_cmd_pair.sql2
        INTO _bool2;
      EXCEPTION WHEN OTHERS THEN
        _error2 := SQLERRM;
      END;
      IF _bool1 IS NOT DISTINCT FROM _bool2
      AND (_error1 IS NULL) = (_error2 IS NULL)
      THEN
        -- OK
      ELSE
        RAISE WARNING E'\nSQL queries produced different results:\n%\n%\n%\n%\n', _sql_cmd_pair.sql1, COALESCE(_bool1::text, _error1), _sql_cmd_pair.sql2, COALESCE(_bool2::text, _error2);
        _failed := _failed + 1;
      END IF;
      _tests := _tests + 1;
    END LOOP;
  END LOOP;
END LOOP;
RAISE NOTICE E'\n========================\n % of % tests failed.\n========================\n', _failed, _tests;
END
$$;
