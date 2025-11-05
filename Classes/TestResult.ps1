enum ResultStatus {
    Pass
    Fail
}

class TestResult {
    [string]$ResourceId
    [string]$ResourceName
    [string]$ResourceGroupName
    [string]$SubscriptionId
    [string]$Category
    [string]$SubCategory
    [string]$TestName
    [string]$TestDescription
    [datetime]$TimeStamp
    [object]$ExpectedResult
    [object]$ActualResult
    [object]$RawResult
    [ResultStatus]$ResultStatus
    
    # Constructor - automatically set TimeStamp
    TestResult() {
        $this.TimeStamp = Get-Date
    }
}