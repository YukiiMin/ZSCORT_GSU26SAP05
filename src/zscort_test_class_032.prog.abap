*&---------------------------------------------------------------------*
*& Report ZSCORT_TEST_CLASS_032
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT ZSCORT_TEST_CLASS_032.
DATA: lo_repo TYPE REF TO zcl_scort_repository_032,
      lt_obj  TYPE zscort_t_objects,
      lt_stat TYPE zscort_t_statistics.

DATA: lr_devclass TYPE RANGE OF tadir-devclass.
lr_devclass = VALUE #( ( sign = 'I' option = 'EQ' low = 'ZSCORT' ) ).

CREATE OBJECT lo_repo.

lo_repo->get_objects(
  IMPORTING et_objects = lt_obj
).

WRITE: / 'Objects found:', lines( lt_obj ).
