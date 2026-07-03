interface ZIF_SCORT_CONSTANTS public.
  constants:
    gc_obj_prog type tadir-object value 'PROG',
    gc_obj_clas type tadir-object value 'CLAS',
    gc_obj_tabl type tadir-object value 'TABL',
    gc_obj_doma type tadir-object value 'DOMA',
    gc_obj_dtel type tadir-object value 'DTEL',
    gc_obj_fugr type tadir-object value 'FUGR',
    gc_obj_tran type tadir-object value 'TRAN'.

  methods get_object_label
    importing
      iv_object type trobjtype
    returning
      value(rv_label) type string.

  methods get_valid_types
    returning
      value(rt_types) type zscort_tt_valid_types.
endinterface.
