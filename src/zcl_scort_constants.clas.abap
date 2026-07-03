class ZCL_SCORT_CONSTANTS definition
  public
  final
  create public
  global friends ZIF_SCORT_CONSTANTS.

public section.

  interfaces ZIF_SCORT_CONSTANTS.

  constants:
    GC_OBJ_PROG type TADIR-OBJECT value 'PROG',
    GC_OBJ_CLAS type TADIR-OBJECT value 'CLAS',
    GC_OBJ_TABL type TADIR-OBJECT value 'TABL',
    GC_OBJ_DOMA type TADIR-OBJECT value 'DOMA',
    GC_OBJ_DTEL type TADIR-OBJECT value 'DTEL',
    GC_OBJ_FUGR type TADIR-OBJECT value 'FUGR',
    GC_OBJ_TRAN type TADIR-OBJECT value 'TRAN'.

protected section.
private section.
endclass.



CLASS ZCL_SCORT_CONSTANTS IMPLEMENTATION.

  METHOD zif_scort_constants~get_object_label.
    rv_label = SWITCH #(
      iv_object
      WHEN zif_scort_constants~gc_obj_prog THEN 'Programs / Reports'
      WHEN zif_scort_constants~gc_obj_clas THEN 'ABAP Classes'
      WHEN zif_scort_constants~gc_obj_tabl THEN 'Database Tables'
      WHEN zif_scort_constants~gc_obj_doma THEN 'Domains'
      WHEN zif_scort_constants~gc_obj_dtel THEN 'Data Elements'
      WHEN zif_scort_constants~gc_obj_fugr THEN 'Function Groups'
      WHEN zif_scort_constants~gc_obj_tran THEN 'Transactions'
      ELSE |{ iv_object }|
    ).
  ENDMETHOD.

  METHOD zif_scort_constants~get_valid_types.
    rt_types = VALUE #(
      ( sign = 'I' option = 'EQ' low = zif_scort_constants~gc_obj_prog )
      ( sign = 'I' option = 'EQ' low = zif_scort_constants~gc_obj_clas )
      ( sign = 'I' option = 'EQ' low = zif_scort_constants~gc_obj_tabl )
      ( sign = 'I' option = 'EQ' low = zif_scort_constants~gc_obj_doma )
      ( sign = 'I' option = 'EQ' low = zif_scort_constants~gc_obj_dtel )
      ( sign = 'I' option = 'EQ' low = zif_scort_constants~gc_obj_fugr )
      ( sign = 'I' option = 'EQ' low = zif_scort_constants~gc_obj_tran )
    ).
  ENDMETHOD.

ENDCLASS.
