*** Settings ***
Force Tags        regression    pybot    jybot
Suite Setup       Run original tests
Suite Teardown    Remove Files    ${ORIGINAL}    ${RERUN}    ${RERUN 2}
Resource          rebot_resource.robot

*** Variables ***
${TEST CASES}     ${DATADIR}/misc/suites
${ORIGINAL}       %{TEMPDIR}/merge-original.xml
${RERUN}          %{TEMPDIR}/merge-rerun.xml
${RERUN 2}        %{TEMPDIR}/merge-rerun-2.xml
@{ALL TESTS}      Suite4 First             SubSuite1 First    SubSuite2 First
...               Test From Sub Suite 4    SubSuite3 First    SubSuite3 Second
...               Suite1 First             Suite1 Second      Third In Suite1
...               Suite2 First             Suite3 First
@{ALL SUITES}     Fourth                   Subsuites          Subsuites2
...               Tsuite1                  Tsuite2            Tsuite3
@{SUB SUITES 1}   Sub1                     Sub2
@{SUB SUITES 2}   Sub.suite.4              Subsuite3
@{RERUN TESTS}    Suite4 First             SubSuite1 First
@{RERUN SUITES}   Fourth                   Subsuites

*** Test Cases ***
Successful merge
    Rerun tests
    Run merge
    Merge should have been successful

Successful multi-merge
    Rerun tests
    Rerun tests again
    Run multi-merge
    ${message} =    Create expected multi-merge message
    Merge should have been successful    status 2=FAIL    message 2=${message}

Non-matching root suite
    Create output with incompatible root suite
    Run merge
    Stderr Should Be Equal To
    ...    [ ERROR ] Merged suite 'Incompatible' is ignored because it is not found from original result.\n
    Verify original tests

Non-matching child suite
    Create output with incompatible child suite
    Run merge
    Stderr Should Be Equal To    SEPARATOR=
    ...    [ ERROR ] Merged suite 'Suites.Sub1' is ignored because it is not found from original result.\n
    ...    [ ERROR ] Merged suite 'Suites.Sub2' is ignored because it is not found from original result.\n
    Verify original tests

Non-matching test
    Create output with incompatible test
    Run merge
    Stderr Should Be Equal To
    ...    [ ERROR ] Merged test 'Suites.Fourth.Non-existing' is ignored because it is not found from original result.\n
    Merge should have been successful    message 1=Expected

Using other options
    [Documentation]  Test that other command line options works normally with
    ...              --rerunmerge. Most importantly verify that options handled
    ...              by ExecutionResult (--flattenkeyword) work correctly.
    Rerun tests
    Run merge    --log log.html --flattenkeyword name:BuiltIn.Log --name Custom
    Merge should have been successful    suite name=Custom
    Log should have been created with all Log keywords flattened

*** Keywords **
Run original tests
    Create Output With Robot    ${ORIGINAL}    --variable FAIL:YES    ${TEST CASES}
    Verify original tests

Verify original tests
    Should Be Equal    ${SUITE.name}    Suites
    Should Contain Suites    ${SUITE}    @{ALL SUITES}
    Should Contain Suites    ${SUITE.suites[1]}    @{SUB SUITES 1}
    Should Contain Suites    ${SUITE.suites[2]}    @{SUB SUITES 2}
    Check Suite Contains Tests    ${SUITE}    @{ALL TESTS}
    ...    SubSuite1 First=FAIL:This test was doomed to fail: YES != NO

Rerun tests
    Create Output With Robot    ${RERUN}    --rerunfailed ${ORIGINAL}    ${TEST CASES}
    Should Be Equal    ${SUITE.name}    Suites
    Should Contain Suites    ${SUITE}    @{RERUN SUITES}
    Should Contain Suites    ${SUITE.suites[1]}    @{SUB SUITES 1}[0]
    Check Suite Contains Tests    ${SUITE}    @{RERUN TESTS}

Rerun tests again
    Create Output With Robot    ${RERUN 2}    --test SubSuite1First --variable FAIL:again    ${TEST CASES}

Create output with incompatible root suite
    Create Output With Robot    ${RERUN}    --name Incompatible --test SubSuite1First    ${TEST CASES}

Create output with incompatible child suite
    Create Output With Robot    ${RERUN}    --name Suites    ${TEST CASES}/subsuites

Create output with incompatible test
    Rerun tests
    ${xml} =    Parse XML    ${RERUN}
    Log Element    ${xml}
    Set Element Attribute    ${xml}    name    Non-existing    xpath=suite/suite/test
    Save XML    ${xml}    ${RERUN}

Run merge
    [Arguments]    ${options}=
    Run Rebot    --rerunmerge ${options}    ${ORIGINAL}    ${RERUN}

Run multi-merge
    Run Rebot    -R    ${ORIGINAL}    ${RERUN}    ${RERUN 2}

Merge should have been successful
    [Arguments]    ${suite name}=Suites    ${status 1}=FAIL    ${message 1}=
    ...    ${status 2}=PASS    ${message 2}=
    Should Be Equal    ${SUITE.name}    ${suite name}
    Should Contain Suites    ${SUITE}    @{ALL SUITES}
    Should Contain Suites    ${SUITE.suites[1]}    @{SUB SUITES 1}
    Should Contain Suites    ${SUITE.suites[2]}    @{SUB SUITES 2}
    ${message 1} =    Create expected merge message    ${message 1}
    ...    FAIL    Expected    FAIL    Expected
    ${message 2} =    Create expected merge message    ${message 2}
    ...    PASS    ${EMPTY}    FAIL    This test was doomed to fail: YES != NO
    Check Suite Contains Tests    ${SUITE}    @{ALL TESTS}
    ...    Suite4 First=${status 1}:${message 1}
    ...    SubSuite1 First=${status 2}:${message 2}

Create expected merge message
    [Arguments]    ${message}    ${new status}    ${new message}    ${old status}    ${old message}
    Return From Keyword If    """${message}"""    ${message}
    Run Keyword And Return    Catenate    SEPARATOR=\n
    ...    Test has been re-run and results replaced.
    ...    - \ - \ -
    ...    New status: \ ${new status}
    ...    New message: \ ${new message}
    ...    - \ - \ -
    ...    Old status: \ ${old status}
    ...    Old message: \ ${old message}

Create expected multi-merge message
    ${message} =    Create expected merge message    ${EMPTY}
    ...    PASS    ${EMPTY}    FAIL    This test was doomed to fail: YES != NO
    ${message} =    Create expected merge message    ${EMPTY}
    ...    FAIL    This test was doomed to fail: again != NO    PASS    ${message}
    [Return]    ${message}

Log should have been created with all Log keywords flattened
    ${log} =    Get File    ${OUTDIR}/log.html
    Should Not Contain    ${log}    "*<p>Logs the given message with the given level.\\x3c/p>"
    Should Contain    ${log}    "*<p>Logs the given message with the given level.\\x3c/p>\\n<p><i><b>Keyword content flattened.\\x3c/b>\\x3c/i>\\x3c/p>"
