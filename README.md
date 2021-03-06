<h1 id="top">🧐🐘<code>anyarray_anyelement_operators-v4.patch</code></h1>

1. [About](#about)
1. [Installation](#installation)
1. [Usage](#usage)
1. [Review](#review)
    1. [doc/src/sgml/func.sgml](#func-sgml)
    1. [doc/src/sgml/gin.sgml](#gin-sgml)
    1. [doc/src/sgml/indices.sgml](#indices-sgml)
    1. [src/backend/access/gin/ginarrayproc.c](#ginarrayproc-c)
    1. [src/backend/utils/adt/arrayfuncs.c](#arrayfuncs-c)
    1. [src/include/catalog/pg_amop.dat](#pg_amop-dat)
    1. [src/include/catalog/pg_operator.dat](#pg_operator-dat)
    1. [src/include/catalog/pg_proc.dat](#pg_proc-dat)
    1. [src/test/regress/expected/arrays.out](#arrays-out)
    1. [src/test/regress/expected/opr_sanity.out](#opr_sanity-out)
    1. [src/test/regress/sql/arrays.sql](#arrays-sql)

<h2 id="about">1. About</h2>

This is a review of Mark Rofail's patch [anyarray_anyelement_operators-v4.patch] submitted to the [Commitfest-2021-03].

    $ sha512sum anyarray_anyelement_operators-v4.patch
    46577c68b043eb7164185b36485581028921a6d239f3dfb311e4175ceabeb1191f62a71a8f9fc1ab7f59e95e18bbcf209ed98f5aa5a8540faf0afe5dc0b00b79

[anyarray_anyelement_operators-v4.patch]: https://www.postgresql.org/message-id/attachment/119360/anyarray_anyelement_operators-v4.patch
[Commitfest-2021-03]: https://commitfest.postgresql.org/32/2966/

<h2 id="installation">2. Installation</h2>

Patch and compile `PostgreSQL` with:

    $ git clone git://git.postgresql.org/git/postgresql.git
    $ cd postgresql
    $ patch -p1 < ~/Downloads/anyarray_anyelement_operators-v4.patch
    $ ./configure --prefix=$HOME/pg-head
    $ make -j16
    $ make install
    $ export PATH=$HOME/pg-head/bin:$PATH
    $ initdb -E UTF8 -k -D $HOME/pg-head-data
    $ pg_ctl -D $HOME/pg-head-data -l /tmp/logfile start
    $ createdb $USER
    $ make installcheck

    =======================
    All 202 tests passed.
    =======================

To run test the `type-test.sql` script, first run the PostgreSQL regressions test, see above, then:

    $ git clone https://github.com/joelonsql/anyarray_anyelement_operators.git
    $ cd anyarray_anyelement_operators
    $ psql -f type-test.sql regression

    ========================
    0 of 5202 tests failed.
    ========================

The generated commands can be extracted to create a test sql/expected pair,
for inclusion in the normal test suite, should it be desired.

    $ psql -f type-test.sql regression 2> type-test.out
    $ grep -A 3 -E '^-- TEST:' type-test.out | grep -v -E '^--' > anyarray_anyelement_operators.sql
    $ grep -A 6 -E '^-- EXPECTED:' type-test.out | grep -v -E '^--' > anyarray_anyelement_operators.expected

The `anyarray_anyelement_operators.expected` file can then later be verified to produce the same output
as running the `anyarray_anyelement_operators.sql` file.

    $ psql -e -t -A -f anyarray_anyelement_operators.sql regression > anyarray_anyelement_operators.out
    $ diff anyarray_anyelement_operators.expected anyarray_anyelement_operators.out && echo OK

The test will show any differences found between the `@>>` and `<<@` operator and `ANY()` for
values of same and different types, mined by digging through all data produced by the PostgreSQL regression tests.

For compatible values, currently only exactly the same types as left and right operands
(where )

<h2 id="usage">3. Usage</h2>

Use with:

    $ psql

```sql
\a
\t

--
-- display 🐘 instead of nothing for NULL values
--
\pset null '🐘'

SELECT ARRAY[]::int[] @>> 1;
f

SELECT ARRAY[1] @>> 1;
t

SELECT ARRAY[2] @>> 1;
f

SELECT ARRAY[2,1] @>> 1;
t

SELECT ARRAY[2,1] @>> 2;
t

SELECT ARRAY[2,1] @>> 3;
f

SELECT ARRAY[2,1] @>> NULL;
🐘

SELECT 1 <<@ ARRAY[]::int[];
f

SELECT 1 <<@ ARRAY[1];
t

SELECT 1 <<@ ARRAY[2];
f

SELECT 1 <<@ ARRAY[2,1];
t

SELECT 2 <<@ ARRAY[2,1];
t

SELECT 3 <<@ ARRAY[2,1];
f

SELECT NULL <<@ ARRAY[2,1];
🐘

```

<h2 id="review">4. Review</h2>

<h3 id="func-sgml"><code>doc/src/sgml/func.sgml</code></h3>

```diff
diff --git a/doc/src/sgml/func.sgml b/doc/src/sgml/func.sgml
index 1ab31a9056..a7cfb16d8b 100644
--- a/doc/src/sgml/func.sgml
+++ b/doc/src/sgml/func.sgml
@@ -17525,6 +17525,34 @@ SELECT NULLIF(value, '(none)') ...
        </para></entry>
       </row>
 
+      <row>
+       <entry role="func_table_entry"><para role="func_signature">
+        <type>anyarray</type> <literal>@&gt;&gt;</literal> <type>anyelement</type>
+        <returnvalue>boolean</returnvalue>
+       </para>
+       <para>
+        Does the array contain specified element?
+       </para>
+       <para>
+        <literal>ARRAY[1,4,3] @&gt;&gt; 3</literal>
+        <returnvalue>t</returnvalue>
+       </para></entry>
+      </row>
+
+      <row>
+       <entry role="func_table_entry"><para role="func_signature">
+        <type>anyelement</type> <literal>&lt;&lt;@</literal> <type>anyarray</type>
+        <returnvalue>boolean</returnvalue>
+       </para>
+       <para>
+        Is the specified element contained in the array?
+       </para>
+       <para>
+        <literal>2 &lt;&lt;@ ARRAY[1,7,4,2,6]</literal>
+        <returnvalue>t</returnvalue>
+       </para></entry>
+      </row>
+
       <row>
        <entry role="func_table_entry"><para role="func_signature">
         <type>anyarray</type> <literal>&amp;&amp;</literal> <type>anyarray</type>
```

<h3 id="gin-sgml"><code>doc/src/sgml/gin.sgml</code></h3>

```diff
diff --git a/doc/src/sgml/gin.sgml b/doc/src/sgml/gin.sgml
index d68d12d515..981513b765 100644
--- a/doc/src/sgml/gin.sgml
+++ b/doc/src/sgml/gin.sgml
@@ -84,7 +84,7 @@
     </thead>
     <tbody>
      <row>
-      <entry morerows="3" valign="middle"><literal>array_ops</literal></entry>
+      <entry morerows="5" valign="middle"><literal>array_ops</literal></entry>
       <entry><literal>&amp;&amp; (anyarray,anyarray)</literal></entry>
      </row>
      <row>
@@ -93,6 +93,12 @@
      <row>
       <entry><literal>&lt;@ (anyarray,anyarray)</literal></entry>
      </row>
+     <row>
+      <entry><literal>@&gt;&gt; (anyarray,anyelement)</literal></entry>
+     </row>
+     <row>
+      <entry><literal>&lt;&lt;@ (anyelement,anyarray)</literal></entry>
+     </row>
      <row>
       <entry><literal>= (anyarray,anyarray)</literal></entry>
      </row>
```

<h3 id="indices-sgml"><code>doc/src/sgml/indices.sgml</code></h3>

```diff
diff --git a/doc/src/sgml/indices.sgml b/doc/src/sgml/indices.sgml
index 623962d1d8..6de6c33c75 100644
--- a/doc/src/sgml/indices.sgml
+++ b/doc/src/sgml/indices.sgml
@@ -326,7 +326,7 @@ SELECT * FROM places ORDER BY location <-> point '(101,456)' LIMIT 10;
    for arrays, which supports indexed queries using these operators:
 
 <synopsis>
-&lt;@ &nbsp; @&gt; &nbsp; = &nbsp; &amp;&amp;
+&lt;@ &nbsp; @&gt; &nbsp; &lt;&lt;@ &nbsp; @&gt;&gt; &nbsp; = &nbsp; &amp;&amp;
 </synopsis>
 
    (See <xref linkend="functions-array"/> for the meaning of
```

<h3 id="ginarrayproc-c"><code>src/backend/access/gin/ginarrayproc.c</code></h3>

```diff
diff --git a/src/backend/access/gin/ginarrayproc.c b/src/backend/access/gin/ginarrayproc.c
index bf73e32932..b10bd04ec8 100644
--- a/src/backend/access/gin/ginarrayproc.c
+++ b/src/backend/access/gin/ginarrayproc.c
@@ -24,6 +24,7 @@
 #define GinContainsStrategy		2
 #define GinContainedStrategy	3
 #define GinEqualStrategy		4
+#define GinContainsElemStrategy	5
 
 
 /*
@@ -78,8 +79,6 @@ ginarrayextract_2args(PG_FUNCTION_ARGS)
 Datum
 ginqueryarrayextract(PG_FUNCTION_ARGS)
 {
-	/* Make copy of array input to ensure it doesn't disappear while in use */
-	ArrayType  *array = PG_GETARG_ARRAYTYPE_P_COPY(0);
 	int32	   *nkeys = (int32 *) PG_GETARG_POINTER(1);
 	StrategyNumber strategy = PG_GETARG_UINT16(2);
 
@@ -87,21 +86,33 @@ ginqueryarrayextract(PG_FUNCTION_ARGS)
 	/* Pointer	   *extra_data = (Pointer *) PG_GETARG_POINTER(4); */
 	bool	  **nullFlags = (bool **) PG_GETARG_POINTER(5);
 	int32	   *searchMode = (int32 *) PG_GETARG_POINTER(6);
-	int16		elmlen;
-	bool		elmbyval;
-	char		elmalign;
 	Datum	   *elems;
 	bool	   *nulls;
 	int			nelems;
 
-	get_typlenbyvalalign(ARR_ELEMTYPE(array),
-						 &elmlen, &elmbyval, &elmalign);
+	if (strategy == GinContainsElemStrategy)
+	{
+		/* single element is passed, set elems to its pointer */
+		elems = &PG_GETARG_DATUM(0);
+		nulls = &PG_ARGISNULL(0);
+		nelems = 1;
+	}
+	else
+	{
+		/* Make copy of array input to ensure it doesn't disappear while in use */
+		ArrayType  *array = PG_GETARG_ARRAYTYPE_P_COPY(0);
+		int16		elmlen;
+		bool		elmbyval;
+		char		elmalign;
 
-	deconstruct_array(array,
-					  ARR_ELEMTYPE(array),
-					  elmlen, elmbyval, elmalign,
-					  &elems, &nulls, &nelems);
+		get_typlenbyvalalign(ARR_ELEMTYPE(array),
+							 &elmlen, &elmbyval, &elmalign);
 
+		deconstruct_array(array,
+						  ARR_ELEMTYPE(array),
+						  elmlen, elmbyval, elmalign,
+						  &elems, &nulls, &nelems);
+	}
 	*nkeys = nelems;
 	*nullFlags = nulls;
 
@@ -126,6 +137,14 @@ ginqueryarrayextract(PG_FUNCTION_ARGS)
 			else
 				*searchMode = GIN_SEARCH_MODE_INCLUDE_EMPTY;
 			break;
+		case GinContainsElemStrategy:
+			/*
+			 * only items that match the queried element
+			 * are considered candidate
+			 */
+
+			*searchMode = GIN_SEARCH_MODE_DEFAULT;
+			break;
 		default:
 			elog(ERROR, "ginqueryarrayextract: unknown strategy number: %d",
 				 strategy);
@@ -185,6 +204,7 @@ ginarrayconsistent(PG_FUNCTION_ARGS)
 				}
 			}
 			break;
+		case GinContainsElemStrategy:
 		case GinContainedStrategy:
 			/* we will need recheck */
 			*recheck = true;
@@ -274,6 +294,7 @@ ginarraytriconsistent(PG_FUNCTION_ARGS)
 				}
 			}
 			break;
+		case GinContainsElemStrategy:
 		case GinContainedStrategy:
 			/* can't do anything else useful here */
 			res = GIN_MAYBE;
```

<h3 id="arrayfuncs-c"><code>src/backend/utils/adt/arrayfuncs.c</code></h3>

```diff
diff --git a/src/backend/utils/adt/arrayfuncs.c b/src/backend/utils/adt/arrayfuncs.c
index f7012cc5d9..8650c62201 100644
--- a/src/backend/utils/adt/arrayfuncs.c
+++ b/src/backend/utils/adt/arrayfuncs.c
@@ -4328,6 +4328,143 @@ arraycontained(PG_FUNCTION_ARGS)
 }
 
 
+/*
+ * array_contains_elem : checks an array for a specific element adapted from
+ * array_contain_compare() for containment of a single element
+ */
+static bool
+array_contains_elem(AnyArrayType *array, Datum elem, Oid elemtype,
+					Oid collation,	void **fn_extra)
+{
+	LOCAL_FCINFO(locfcinfo, 2);
+	Oid 		arrtype = AARR_ELEMTYPE(array);
+	TypeCacheEntry *typentry;
+	int 		nelems;
+	int			typlen;
+	bool		typbyval;
+	char		typalign;
+	int			i;
+	array_iter 	it;
+
+	if (arrtype != elemtype)
+		ereport(ERROR,
+				(errcode(ERRCODE_DATATYPE_MISMATCH),
+				 errmsg("cannot compare arrays elements with element of different type")));
+
+	/*
+	 * We arrange to look up the equality function only once per series of
+	 * calls, assuming the element type doesn't change underneath us.  The
+	 * typcache is used so that we have no memory leakage when being used as
+	 * an index support function.
+	 */
+	typentry = (TypeCacheEntry *) *fn_extra;
+	if (typentry == NULL ||
+		typentry->type_id != arrtype)
+	{
+		typentry = lookup_type_cache(arrtype,
+									 TYPECACHE_EQ_OPR_FINFO);
+		if (!OidIsValid(typentry->eq_opr_finfo.fn_oid))
+			ereport(ERROR,
+					(errcode(ERRCODE_UNDEFINED_FUNCTION),
+					 errmsg("could not identify an equality operator for type %s",
+							format_type_be(arrtype))));
+		*fn_extra = (void *) typentry;
+	}
+	typlen = typentry->typlen;
+	typbyval = typentry->typbyval;
+	typalign = typentry->typalign;
+
+	/*
+	 * Apply the comparison operator for the passed element against each
+	 * element in the array
+	 */
+	InitFunctionCallInfoData(*locfcinfo, &typentry->eq_opr_finfo, 2,
+							 collation, NULL, NULL);
+
+	/* Loop over source data */
+	nelems = ArrayGetNItems(AARR_NDIM(array), AARR_DIMS(array));
+	array_iter_setup(&it, array);
+
+	for (i = 0; i < nelems; i++)
+	{
+		Datum elt;
+		bool isnull;
+		bool oprresult;
+
+		/* Get element, checking for NULL */
+		elt = array_iter_next(&it, &isnull, i, typlen, typbyval, typalign);
+
+		/*
+		 * We assume that the comparison operator is strict, so a NULL can't
+		 * match anything. refer to the comment in array_contain_compare()
+		 */
+		if (isnull)
+			continue;
+
+		/*
+		 * Apply the operator to the element pair; treat NULL as false
+		 */
+		locfcinfo->args[0].value = elt;
+		locfcinfo->args[0].isnull = false;
+		locfcinfo->args[1].value = elem;
+		locfcinfo->args[1].isnull = false;
+		locfcinfo->isnull = false;
+		oprresult = DatumGetBool(FunctionCallInvoke(locfcinfo));
+		if (!locfcinfo->isnull && oprresult)
+			return true;
+	}
+
+	return false;
+}
+
+Datum
+arraycontainselem(PG_FUNCTION_ARGS)
+{
+	AnyArrayType *array = PG_GETARG_ANY_ARRAY_P(0);
+	Datum elem = PG_GETARG_DATUM(1);
+	Oid	elemtype = get_fn_expr_argtype(fcinfo->flinfo, 1);
+	Oid collation = PG_GET_COLLATION();
+	bool result;
+
+	/*
+	 * we don't need to check if the elem is null or if the elem datatype and
+	 * array datatype match since this is handled within internal calls already
+	 * (a property of polymorphic functions)
+	 */
+
+	result = array_contains_elem(array, elem, elemtype, collation,
+								 &fcinfo->flinfo->fn_extra);
+
+	/* Avoid leaking memory when handed toasted input */
+	AARR_FREE_IF_COPY(array, 0);
+
+	PG_RETURN_BOOL(result);
+}
+
+Datum
+arrayelemcontained(PG_FUNCTION_ARGS)
+{
+	AnyArrayType *array = PG_GETARG_ANY_ARRAY_P(1);
+	Datum elem = PG_GETARG_DATUM(0);
+	Oid	elemtype = get_fn_expr_argtype(fcinfo->flinfo, 0);
+	Oid collation = PG_GET_COLLATION();
+	bool result;
+
+	/*
+	 * we don't need to check if the elem is null or if the elem datatype and
+	 * array datatype match since this is handled within internal calls already
+	 * (a property of polymorphic functions)
+	 */
+
+	result = array_contains_elem(array, elem, elemtype, collation,
+								 &fcinfo->flinfo->fn_extra);
+
+	/* Avoid leaking memory when handed toasted input */
+	AARR_FREE_IF_COPY(array, 1);
+
+	PG_RETURN_BOOL(result);
+}
+
 /*-----------------------------------------------------------------------------
  * Array iteration functions
  *		These functions are used to iterate efficiently through arrays
```

<h3 id="pg_amop-dat"><code>src/include/catalog/pg_amop.dat</code></h3>

```diff
diff --git a/src/include/catalog/pg_amop.dat b/src/include/catalog/pg_amop.dat
index 0f7ff63669..8a14fc7140 100644
--- a/src/include/catalog/pg_amop.dat
+++ b/src/include/catalog/pg_amop.dat
@@ -1242,6 +1242,9 @@
 { amopfamily => 'gin/array_ops', amoplefttype => 'anyarray',
   amoprighttype => 'anyarray', amopstrategy => '4',
   amopopr => '=(anyarray,anyarray)', amopmethod => 'gin' },
+{ amopfamily => 'gin/array_ops', amoplefttype => 'anyarray',
+  amoprighttype => 'anyelement', amopstrategy => '5',
+  amopopr => '@>>(anyarray,anyelement)', amopmethod => 'gin' },
 
 # btree enum_ops
 { amopfamily => 'btree/enum_ops', amoplefttype => 'anyenum',
```

<h3 id="pg_operator-dat"><code>src/include/catalog/pg_operator.dat</code></h3>

```diff
diff --git a/src/include/catalog/pg_operator.dat b/src/include/catalog/pg_operator.dat
index 0d4eac8f96..7ef071135c 100644
--- a/src/include/catalog/pg_operator.dat
+++ b/src/include/catalog/pg_operator.dat
@@ -2761,7 +2761,7 @@
   oprresult => 'bool', oprcode => 'circle_overabove', oprrest => 'positionsel',
   oprjoin => 'positionjoinsel' },
 
-# overlap/contains/contained for arrays
+# overlap/contains/contained/elemcontained/containselem for arrays
 { oid => '2750', oid_symbol => 'OID_ARRAY_OVERLAP_OP', descr => 'overlaps',
   oprname => '&&', oprleft => 'anyarray', oprright => 'anyarray',
   oprresult => 'bool', oprcom => '&&(anyarray,anyarray)',
@@ -2778,6 +2778,18 @@
   oprresult => 'bool', oprcom => '@>(anyarray,anyarray)',
   oprcode => 'arraycontained', oprrest => 'arraycontsel',
   oprjoin => 'arraycontjoinsel' },
+{ oid => '6108', oid_symbol => 'OID_ARRAY_ELEMCONTAINED_OP',
+  descr => 'elem is contained by',
+  oprname => '<<@', oprleft => 'anyelement', oprright => 'anyarray',
+  oprresult => 'bool', oprcom => '@>>(anyarray,anyelement)',
+  oprcode => 'arrayelemcontained', oprrest => 'arraycontsel',
+  oprjoin => 'arraycontjoinsel' },
+{ oid => '6105', oid_symbol => 'OID_ARRAY_CONTAINSELEM_OP',
+  descr => 'contains elem',
+  oprname => '@>>', oprleft => 'anyarray', oprright => 'anyelement',
+  oprresult => 'bool', oprcom => '<<@(anyelement,anyarray)',
+  oprcode => 'arraycontainselem', oprrest => 'arraycontsel',
+  oprjoin => 'arraycontjoinsel' },
 
 # capturing operators to preserve pre-8.3 behavior of text concatenation
 { oid => '2779', descr => 'concatenate',
```

<h3 id="pg_proc-dat"><code>src/include/catalog/pg_proc.dat</code></h3>

```diff
diff --git a/src/include/catalog/pg_proc.dat b/src/include/catalog/pg_proc.dat
index 1487710d59..aa9d9f7291 100644
--- a/src/include/catalog/pg_proc.dat
+++ b/src/include/catalog/pg_proc.dat
@@ -8180,6 +8180,12 @@
 { oid => '2749',
   proname => 'arraycontained', prorettype => 'bool',
   proargtypes => 'anyarray anyarray', prosrc => 'arraycontained' },
+{ oid => '6109',
+  proname => 'arrayelemcontained', prorettype => 'bool',
+  proargtypes => 'anyelement anyarray', prosrc => 'arrayelemcontained' },
+{ oid => '6107',
+  proname => 'arraycontainselem', prorettype => 'bool',
+  proargtypes => 'anyarray anyelement', prosrc => 'arraycontainselem' },
 
 # BRIN minmax
 { oid => '3383', descr => 'BRIN minmax support',
```

<h3 id="arrays-out"><code>src/test/regress/expected/arrays.out</code></h3>

```diff
diff --git a/src/test/regress/expected/arrays.out b/src/test/regress/expected/arrays.out
index 8bc7721e7d..95c9ae5443 100644
--- a/src/test/regress/expected/arrays.out
+++ b/src/test/regress/expected/arrays.out
@@ -758,6 +758,28 @@ SELECT * FROM array_op_test WHERE i @> '{32}' ORDER BY seqno;
    100 | {85,32,57,39,49,84,32,3,30}     | {AAAAAAA80240,AAAAAAAAAAAAAAAA1729,AAAAA60038,AAAAAAAAAAA92631,AAAAAAAA9523}
 (6 rows)
 
+SELECT * FROM array_op_test WHERE i @>> 32 ORDER BY seqno;
+ seqno |                i                |                                                                 t                                                                  
+-------+---------------------------------+------------------------------------------------------------------------------------------------------------------------------------
+     6 | {39,35,5,94,17,92,60,32}        | {AAAAAAAAAAAAAAA35875,AAAAAAAAAAAAAAAA23657}
+    74 | {32}                            | {AAAAAAAAAAAAAAAA1729,AAAAAAAAAAAAA22860,AAAAAA99807,AAAAA17383,AAAAAAAAAAAAAAA67062,AAAAAAAAAAA15165,AAAAAAAAAAA50956}
+    77 | {97,15,32,17,55,59,18,37,50,39} | {AAAAAAAAAAAA67946,AAAAAA54032,AAAAAAAA81587,55847,AAAAAAAAAAAAAA28620,AAAAAAAAAAAAAAAAA43052,AAAAAA75463,AAAA49534,AAAAAAAA44066}
+    89 | {40,32,17,6,30,88}              | {AA44673,AAAAAAAAAAA6119,AAAAAAAAAAAAAAAA23657,AAAAAAAAAAAAAAAAAA47955,AAAAAAAAAAAAAAAA33598,AAAAAAAAAAA33576,AA44673}
+    98 | {38,34,32,89}                   | {AAAAAAAAAAAAAAAAAA71621,AAAA8857,AAAAAAAAAAAAAAAAAAA65037,AAAAAAAAAAAAAAAA31334,AAAAAAAAAA48845}
+   100 | {85,32,57,39,49,84,32,3,30}     | {AAAAAAA80240,AAAAAAAAAAAAAAAA1729,AAAAA60038,AAAAAAAAAAA92631,AAAAAAAA9523}
+(6 rows)
+
+SELECT * FROM array_op_test WHERE 32 <<@ i ORDER BY seqno;
+ seqno |                i                |                                                                 t                                                                  
+-------+---------------------------------+------------------------------------------------------------------------------------------------------------------------------------
+     6 | {39,35,5,94,17,92,60,32}        | {AAAAAAAAAAAAAAA35875,AAAAAAAAAAAAAAAA23657}
+    74 | {32}                            | {AAAAAAAAAAAAAAAA1729,AAAAAAAAAAAAA22860,AAAAAA99807,AAAAA17383,AAAAAAAAAAAAAAA67062,AAAAAAAAAAA15165,AAAAAAAAAAA50956}
+    77 | {97,15,32,17,55,59,18,37,50,39} | {AAAAAAAAAAAA67946,AAAAAA54032,AAAAAAAA81587,55847,AAAAAAAAAAAAAA28620,AAAAAAAAAAAAAAAAA43052,AAAAAA75463,AAAA49534,AAAAAAAA44066}
+    89 | {40,32,17,6,30,88}              | {AA44673,AAAAAAAAAAA6119,AAAAAAAAAAAAAAAA23657,AAAAAAAAAAAAAAAAAA47955,AAAAAAAAAAAAAAAA33598,AAAAAAAAAAA33576,AA44673}
+    98 | {38,34,32,89}                   | {AAAAAAAAAAAAAAAAAA71621,AAAA8857,AAAAAAAAAAAAAAAAAAA65037,AAAAAAAAAAAAAAAA31334,AAAAAAAAAA48845}
+   100 | {85,32,57,39,49,84,32,3,30}     | {AAAAAAA80240,AAAAAAAAAAAAAAAA1729,AAAAA60038,AAAAAAAAAAA92631,AAAAAAAA9523}
+(6 rows)
+
 SELECT * FROM array_op_test WHERE i && '{32}' ORDER BY seqno;
  seqno |                i                |                                                                 t                                                                  
 -------+---------------------------------+------------------------------------------------------------------------------------------------------------------------------------
@@ -782,6 +804,32 @@ SELECT * FROM array_op_test WHERE i @> '{17}' ORDER BY seqno;
     89 | {40,32,17,6,30,88}              | {AA44673,AAAAAAAAAAA6119,AAAAAAAAAAAAAAAA23657,AAAAAAAAAAAAAAAAAA47955,AAAAAAAAAAAAAAAA33598,AAAAAAAAAAA33576,AA44673}
 (8 rows)
 
+SELECT * FROM array_op_test WHERE 17 <<@ i ORDER BY seqno;
+ seqno |                i                |                                                                 t                                                                  
+-------+---------------------------------+------------------------------------------------------------------------------------------------------------------------------------
+     6 | {39,35,5,94,17,92,60,32}        | {AAAAAAAAAAAAAAA35875,AAAAAAAAAAAAAAAA23657}
+    12 | {17,99,18,52,91,72,0,43,96,23}  | {AAAAA33250,AAAAAAAAAAAAAAAAAAA85420,AAAAAAAAAAA33576}
+    15 | {17,14,16,63,67}                | {AA6416,AAAAAAAAAA646,AAAAA95309}
+    19 | {52,82,17,74,23,46,69,51,75}    | {AAAAAAAAAAAAA73084,AAAAA75968,AAAAAAAAAAAAAAAA14047,AAAAAAA80240,AAAAAAAAAAAAAAAAAAA1205,A68938}
+    53 | {38,17}                         | {AAAAAAAAAAA21658}
+    65 | {61,5,76,59,17}                 | {AAAAAA99807,AAAAA64741,AAAAAAAAAAA53908,AA21643,AAAAAAAAA10012}
+    77 | {97,15,32,17,55,59,18,37,50,39} | {AAAAAAAAAAAA67946,AAAAAA54032,AAAAAAAA81587,55847,AAAAAAAAAAAAAA28620,AAAAAAAAAAAAAAAAA43052,AAAAAA75463,AAAA49534,AAAAAAAA44066}
+    89 | {40,32,17,6,30,88}              | {AA44673,AAAAAAAAAAA6119,AAAAAAAAAAAAAAAA23657,AAAAAAAAAAAAAAAAAA47955,AAAAAAAAAAAAAAAA33598,AAAAAAAAAAA33576,AA44673}
+(8 rows)
+
+SELECT * FROM array_op_test WHERE i @>> 17 ORDER BY seqno;
+ seqno |                i                |                                                                 t                                                                  
+-------+---------------------------------+------------------------------------------------------------------------------------------------------------------------------------
+     6 | {39,35,5,94,17,92,60,32}        | {AAAAAAAAAAAAAAA35875,AAAAAAAAAAAAAAAA23657}
+    12 | {17,99,18,52,91,72,0,43,96,23}  | {AAAAA33250,AAAAAAAAAAAAAAAAAAA85420,AAAAAAAAAAA33576}
+    15 | {17,14,16,63,67}                | {AA6416,AAAAAAAAAA646,AAAAA95309}
+    19 | {52,82,17,74,23,46,69,51,75}    | {AAAAAAAAAAAAA73084,AAAAA75968,AAAAAAAAAAAAAAAA14047,AAAAAAA80240,AAAAAAAAAAAAAAAAAAA1205,A68938}
+    53 | {38,17}                         | {AAAAAAAAAAA21658}
+    65 | {61,5,76,59,17}                 | {AAAAAA99807,AAAAA64741,AAAAAAAAAAA53908,AA21643,AAAAAAAAA10012}
+    77 | {97,15,32,17,55,59,18,37,50,39} | {AAAAAAAAAAAA67946,AAAAAA54032,AAAAAAAA81587,55847,AAAAAAAAAAAAAA28620,AAAAAAAAAAAAAAAAA43052,AAAAAA75463,AAAA49534,AAAAAAAA44066}
+    89 | {40,32,17,6,30,88}              | {AA44673,AAAAAAAAAAA6119,AAAAAAAAAAAAAAAA23657,AAAAAAAAAAAAAAAAAA47955,AAAAAAAAAAAAAAAA33598,AAAAAAAAAAA33576,AA44673}
+(8 rows)
+
 SELECT * FROM array_op_test WHERE i && '{17}' ORDER BY seqno;
  seqno |                i                |                                                                 t                                                                  
 -------+---------------------------------+------------------------------------------------------------------------------------------------------------------------------------
@@ -963,6 +1011,16 @@ SELECT * FROM array_op_test WHERE i @> '{NULL}' ORDER BY seqno;
 -------+---+---
 (0 rows)
 
+SELECT * FROM array_op_test WHERE i @>> NULL  ORDER BY seqno;
+ seqno | i | t 
+-------+---+---
+(0 rows)
+
+SELECT * FROM array_op_test WHERE NULL <<@ i ORDER BY seqno;
+ seqno | i | t 
+-------+---+---
+(0 rows)
+
 SELECT * FROM array_op_test WHERE i && '{NULL}' ORDER BY seqno;
  seqno | i | t 
 -------+---+---
@@ -983,6 +1041,24 @@ SELECT * FROM array_op_test WHERE t @> '{AAAAAAAA72908}' ORDER BY seqno;
     79 | {45}                  | {AAAAAAAAAA646,AAAAAAAAAAAAAAAAAAA70415,AAAAAA43678,AAAAAAAA72908}
 (4 rows)
 
+SELECT * FROM array_op_test WHERE t @>> 'AAAAAAAA72908' ORDER BY seqno;
+ seqno |           i           |                                                                     t                                                                      
+-------+-----------------------+--------------------------------------------------------------------------------------------------------------------------------------------
+    22 | {11,6,56,62,53,30}    | {AAAAAAAA72908}
+    45 | {99,45}               | {AAAAAAAA72908,AAAAAAAAAAAAAAAAAAA17075,AA88409,AAAAAAAAAAAAAAAAAA36842,AAAAAAA48038,AAAAAAAAAAAAAA10611}
+    72 | {22,1,16,78,20,91,83} | {47735,AAAAAAA56483,AAAAAAAAAAAAA93788,AA42406,AAAAAAAAAAAAA73084,AAAAAAAA72908,AAAAAAAAAAAAAAAAAA61286,AAAAA66674,AAAAAAAAAAAAAAAAA50407}
+    79 | {45}                  | {AAAAAAAAAA646,AAAAAAAAAAAAAAAAAAA70415,AAAAAA43678,AAAAAAAA72908}
+(4 rows)
+
+SELECT * FROM array_op_test WHERE 'AAAAAAAA72908' <<@ t ORDER BY seqno;
+ seqno |           i           |                                                                     t                                                                      
+-------+-----------------------+--------------------------------------------------------------------------------------------------------------------------------------------
+    22 | {11,6,56,62,53,30}    | {AAAAAAAA72908}
+    45 | {99,45}               | {AAAAAAAA72908,AAAAAAAAAAAAAAAAAAA17075,AA88409,AAAAAAAAAAAAAAAAAA36842,AAAAAAA48038,AAAAAAAAAAAAAA10611}
+    72 | {22,1,16,78,20,91,83} | {47735,AAAAAAA56483,AAAAAAAAAAAAA93788,AA42406,AAAAAAAAAAAAA73084,AAAAAAAA72908,AAAAAAAAAAAAAAAAAA61286,AAAAA66674,AAAAAAAAAAAAAAAAA50407}
+    79 | {45}                  | {AAAAAAAAAA646,AAAAAAAAAAAAAAAAAAA70415,AAAAAA43678,AAAAAAAA72908}
+(4 rows)
+
 SELECT * FROM array_op_test WHERE t && '{AAAAAAAA72908}' ORDER BY seqno;
  seqno |           i           |                                                                     t                                                                      
 -------+-----------------------+--------------------------------------------------------------------------------------------------------------------------------------------
@@ -1000,6 +1076,22 @@ SELECT * FROM array_op_test WHERE t @> '{AAAAAAAAAA646}' ORDER BY seqno;
     96 | {23,97,43}       | {AAAAAAAAAA646,A87088}
 (3 rows)
 
+SELECT * FROM array_op_test WHERE t @>> 'AAAAAAAAAA646' ORDER BY seqno;
+ seqno |        i         |                                 t                                  
+-------+------------------+--------------------------------------------------------------------
+    15 | {17,14,16,63,67} | {AA6416,AAAAAAAAAA646,AAAAA95309}
+    79 | {45}             | {AAAAAAAAAA646,AAAAAAAAAAAAAAAAAAA70415,AAAAAA43678,AAAAAAAA72908}
+    96 | {23,97,43}       | {AAAAAAAAAA646,A87088}
+(3 rows)
+
+SELECT * FROM array_op_test WHERE 'AAAAAAAAAA646' <<@ t ORDER BY seqno;
+ seqno |        i         |                                 t                                  
+-------+------------------+--------------------------------------------------------------------
+    15 | {17,14,16,63,67} | {AA6416,AAAAAAAAAA646,AAAAA95309}
+    79 | {45}             | {AAAAAAAAAA646,AAAAAAAAAAAAAAAAAAA70415,AAAAAA43678,AAAAAAAA72908}
+    96 | {23,97,43}       | {AAAAAAAAAA646,A87088}
+(3 rows)
+
 SELECT * FROM array_op_test WHERE t && '{AAAAAAAAAA646}' ORDER BY seqno;
  seqno |        i         |                                 t                                  
 -------+------------------+--------------------------------------------------------------------
```

<h3 id="opr_sanity-out"><code>src/test/regress/expected/opr_sanity.out</code></h3>

```diff
diff --git a/src/test/regress/expected/opr_sanity.out b/src/test/regress/expected/opr_sanity.out
index 254ca06d3d..5de5ab6d13 100644
--- a/src/test/regress/expected/opr_sanity.out
+++ b/src/test/regress/expected/opr_sanity.out
@@ -1173,6 +1173,7 @@ ORDER BY 1, 2;
  <->  | <->
  <<   | >>
  <<=  | >>=
+ <<@  | @>>
  <=   | >=
  <>   | <>
  <@   | @>
@@ -1188,7 +1189,7 @@ ORDER BY 1, 2;
  ~<=~ | ~>=~
  ~<~  | ~>~
  ~=   | ~=
-(29 rows)
+(30 rows)
 
 -- Likewise for negator pairs.
 SELECT DISTINCT o1.oprname AS op1, o2.oprname AS op2
@@ -2029,6 +2030,7 @@ ORDER BY 1, 2, 3;
        2742 |            2 | @@@
        2742 |            3 | <@
        2742 |            4 | =
+       2742 |            5 | @>>
        2742 |            7 | @>
        2742 |            9 | ?
        2742 |           10 | ?|
@@ -2100,7 +2102,7 @@ ORDER BY 1, 2, 3;
        4000 |           28 | ^@
        4000 |           29 | <^
        4000 |           30 | >^
-(123 rows)
+(124 rows)
 
 -- Check that all opclass search operators have selectivity estimators.
 -- This is not absolutely required, but it seems a reasonable thing
```

<h3 id="arrays-sql"><code>src/test/regress/sql/arrays.sql</code></h3>

```diff
diff --git a/src/test/regress/sql/arrays.sql b/src/test/regress/sql/arrays.sql
index c40619a8d5..b5eec945f7 100644
--- a/src/test/regress/sql/arrays.sql
+++ b/src/test/regress/sql/arrays.sql
@@ -319,8 +319,12 @@ SELECT 0 || ARRAY[1,2] || 3 AS "{0,1,2,3}";
 SELECT ARRAY[1.1] || ARRAY[2,3,4];
 
 SELECT * FROM array_op_test WHERE i @> '{32}' ORDER BY seqno;
+SELECT * FROM array_op_test WHERE i @>> 32 ORDER BY seqno;
+SELECT * FROM array_op_test WHERE 32 <<@ i ORDER BY seqno;
 SELECT * FROM array_op_test WHERE i && '{32}' ORDER BY seqno;
 SELECT * FROM array_op_test WHERE i @> '{17}' ORDER BY seqno;
+SELECT * FROM array_op_test WHERE 17 <<@ i ORDER BY seqno;
+SELECT * FROM array_op_test WHERE i @>> 17 ORDER BY seqno;
 SELECT * FROM array_op_test WHERE i && '{17}' ORDER BY seqno;
 SELECT * FROM array_op_test WHERE i @> '{32,17}' ORDER BY seqno;
 SELECT * FROM array_op_test WHERE i && '{32,17}' ORDER BY seqno;
@@ -331,12 +335,18 @@ SELECT * FROM array_op_test WHERE i && '{}' ORDER BY seqno;
 SELECT * FROM array_op_test WHERE i <@ '{}' ORDER BY seqno;
 SELECT * FROM array_op_test WHERE i = '{NULL}' ORDER BY seqno;
 SELECT * FROM array_op_test WHERE i @> '{NULL}' ORDER BY seqno;
+SELECT * FROM array_op_test WHERE i @>> NULL  ORDER BY seqno;
+SELECT * FROM array_op_test WHERE NULL <<@ i ORDER BY seqno;
 SELECT * FROM array_op_test WHERE i && '{NULL}' ORDER BY seqno;
 SELECT * FROM array_op_test WHERE i <@ '{NULL}' ORDER BY seqno;
 
 SELECT * FROM array_op_test WHERE t @> '{AAAAAAAA72908}' ORDER BY seqno;
+SELECT * FROM array_op_test WHERE t @>> 'AAAAAAAA72908' ORDER BY seqno;
+SELECT * FROM array_op_test WHERE 'AAAAAAAA72908' <<@ t ORDER BY seqno;
 SELECT * FROM array_op_test WHERE t && '{AAAAAAAA72908}' ORDER BY seqno;
 SELECT * FROM array_op_test WHERE t @> '{AAAAAAAAAA646}' ORDER BY seqno;
+SELECT * FROM array_op_test WHERE t @>> 'AAAAAAAAAA646' ORDER BY seqno;
+SELECT * FROM array_op_test WHERE 'AAAAAAAAAA646' <<@ t ORDER BY seqno;
 SELECT * FROM array_op_test WHERE t && '{AAAAAAAAAA646}' ORDER BY seqno;
 SELECT * FROM array_op_test WHERE t @> '{AAAAAAAA72908,AAAAAAAAAA646}' ORDER BY seqno;
 SELECT * FROM array_op_test WHERE t && '{AAAAAAAA72908,AAAAAAAAAA646}' ORDER BY seqno;
```
