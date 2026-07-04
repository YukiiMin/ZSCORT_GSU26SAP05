class ZCL_SCORT_CONSTANTS definition
  public
  final
  create public.

public section.

  constants:
    GC_OBJ_PROG type TADIR-OBJECT value 'PROG',
    GC_OBJ_CLAS type TADIR-OBJECT value 'CLAS',
    GC_OBJ_TABL type TADIR-OBJECT value 'TABL',
    GC_OBJ_DOMA type TADIR-OBJECT value 'DOMA',
    GC_OBJ_DTEL type TADIR-OBJECT value 'DTEL',
    GC_OBJ_FUGR type TADIR-OBJECT value 'FUGR',
    GC_OBJ_TRAN type TADIR-OBJECT value 'TRAN'.

  class-methods get_object_label
    importing
      iv_object type TROBJTYPE
    returning
      value(rv_label) type STRING.

  class-methods get_valid_types
    returning
      value(rt_types) type ZSCORT_TT_VALID_TYPES.

protected section.
private section.
endclass.



CLASS ZCL_SCORT_CONSTANTS IMPLEMENTATION.

  METHOD get_object_label.
    rv_label = SWITCH #(
      iv_object
      WHEN GC_OBJ_PROG THEN 'Programs / Reports'
      WHEN GC_OBJ_CLAS THEN 'ABAP Classes'
      WHEN GC_OBJ_TABL THEN 'Database Tables'
      WHEN GC_OBJ_DOMA THEN 'Domains'
      WHEN GC_OBJ_DTEL THEN 'Data Elements'
      WHEN GC_OBJ_FUGR THEN 'Function Groups'
      WHEN GC_OBJ_TRAN THEN 'Transactions'
      ELSE |{ iv_object }|
    ).
  ENDMETHOD.

  METHOD get_valid_types.
    rt_types = VALUE #(
      ( object = GC_OBJ_PROG label = 'Programs / Reports' )
      ( object = GC_OBJ_CLAS label = 'ABAP Classes' )
      ( object = GC_OBJ_TABL label = 'Database Tables' )
      ( object = GC_OBJ_DOMA label = 'Domains' )
      ( object = GC_OBJ_DTEL label = 'Data Elements' )
      ( object = GC_OBJ_FUGR label = 'Function Groups' )
      ( object = GC_OBJ_TRAN label = 'Transactions' )
    ).
  ENDMETHOD.

ENDCLASS.
