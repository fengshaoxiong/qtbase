# Generated from qpointer.pro.

#####################################################################
## tst_qpointer Test:
#####################################################################

qt_add_test(tst_qpointer
    SOURCES
        tst_qpointer.cpp
)

## Scopes:
#####################################################################

qt_extend_target(tst_qpointer CONDITION TARGET Qt::Widgets
    PUBLIC_LIBRARIES
        Qt::Widgets
)
