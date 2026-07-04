class ZCL_SCORT_FACTORY definition
  public
  final
  create public.

public section.

  class-methods GET_READER
    returning
      VALUE(RO_READER) type ref to ZIF_SCORT_REPO_READER.

  class-methods GET_MUTATOR
    returning
      VALUE(RO_MUTATOR) type ref to ZIF_SCORT_REPO_MUTATOR.

  class-methods GET_CONSTANTS
    returning
      VALUE(RO_CONST) type ref to ZCL_SCORT_CONSTANTS.

protected section.
private section.
  class-data GO_READER type ref to ZIF_SCORT_REPO_READER.
  class-data GO_MUTATOR type ref to ZIF_SCORT_REPO_MUTATOR.
  class-data GO_CONSTANTS type ref to ZCL_SCORT_CONSTANTS.
endclass.



CLASS ZCL_SCORT_FACTORY IMPLEMENTATION.

  METHOD get_constants.
    IF go_constants IS NOT BOUND.
      CREATE OBJECT go_constants TYPE zcl_scort_constants.
    ENDIF.
    ro_const = go_constants.
  ENDMETHOD.

  METHOD get_reader.
    IF go_reader IS NOT BOUND.
      CREATE OBJECT go_reader TYPE zcl_scort_repo_reader_032.
    ENDIF.
    ro_reader = go_reader.
  ENDMETHOD.

  METHOD get_mutator.
    IF go_mutator IS NOT BOUND.
      CREATE OBJECT go_mutator TYPE zcl_scort_repo_mutator_032.
    ENDIF.
    ro_mutator = go_mutator.
  ENDMETHOD.

ENDCLASS.
