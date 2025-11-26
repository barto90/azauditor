function Export-AzAuditorReport {
    <#
    .SYNOPSIS
        Generates a beautiful HTML report from Azure Auditor test results.
    
    .DESCRIPTION
        Creates an interactive HTML report with charts, tabs by category, and detailed test results.
        The report includes a dashboard overview and detailed views for each category.
    
    .PARAMETER Results
        Array of TestResult objects from Start-AzAuditor.
    
    .PARAMETER OutputPath
        Path where the HTML report will be saved. Defaults to current directory with timestamp.
    
    .PARAMETER OpenInBrowser
        If specified, automatically opens the report in the default browser.
    
    .EXAMPLE
        $results = Start-AzAuditor
        Export-AzAuditorReport -Results $results -OpenInBrowser
        
    .OUTPUTS
        String
        Returns the path to the generated HTML report.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Results,
        
        [Parameter()]
        [string]$OutputPath,
        
        [Parameter()]
        [switch]$OpenInBrowser
    )
    
    begin {
        # Suppress JSON serialization depth warnings
        $WarningPreference = 'SilentlyContinue'
        
        if (-not $OutputPath) {
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $OutputPath = Join-Path (Get-Location) "AzureAuditReport_$timestamp.html"
        }
    }
    
    process {
        Write-Verbose "Generating HTML report from $($Results.Count) test result(s)..."
        
        # Calculate statistics
        $totalTests = $Results.Count
        $passedTests = ($Results | Where-Object { $_.ResultStatus -eq 'Pass' }).Count
        $failedTests = ($Results | Where-Object { $_.ResultStatus -eq 'Fail' }).Count
        $passPercentage = if ($totalTests -gt 0) { [math]::Round(($passedTests / $totalTests) * 100, 1) } else { 0 }
        
        # Group by category
        $categoriesData = $Results | Group-Object -Property Category | Sort-Object Name
        
        # Group by subcategory
        $subcategoriesData = $Results | Group-Object -Property Category, SubCategory
        
        # Get unique subscriptions
        $subscriptions = ($Results | Select-Object -ExpandProperty SubscriptionId -Unique).Count
        
        # Generate HTML
        $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Azure Auditor Report - $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"></script>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', -apple-system, BlinkMacSystemFont, sans-serif;
            background: #F3F4F6;
            margin: 0;
            color: #1F2937;
        }
        
        .container {
            display: flex;
            min-height: 100vh;
        }
        
        /* Sidebar Navigation */
        .sidebar {
            width: 260px;
            background: #FFFFFF;
            border-right: 1px solid #E5E7EB;
            padding: 0;
            position: fixed;
            height: 100vh;
            overflow-y: auto;
        }
        
        .sidebar-header {
            padding: 24px 20px;
            background: #0078D4;
            color: white;
        }
        
        .sidebar-header h1 {
            font-size: 18px;
            font-weight: 600;
            margin-bottom: 4px;
        }
        
        .sidebar-header p {
            font-size: 11px;
            opacity: 0.9;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        
        .nav-menu {
            padding: 20px 0;
        }
        
        .nav-item {
            padding: 12px 20px;
            cursor: pointer;
            border-left: 3px solid transparent;
            color: #6B7280;
            font-size: 14px;
            font-weight: 500;
            transition: all 0.2s;
            display: flex;
            align-items: center;
            gap: 12px;
        }
        
        .nav-item:hover {
            background: #F9FAFB;
            color: #0078D4;
        }
        
        .nav-item.active {
            background: #EFF6FF;
            color: #0078D4;
            border-left-color: #0078D4;
        }
        
        .nav-icon {
            font-size: 16px;
            width: 20px;
            text-align: center;
        }
        
        /* Main Content */
        .main-content {
            margin-left: 260px;
            flex: 1;
            padding: 0;
        }
        
        .topbar {
            background: #FFFFFF;
            border-bottom: 1px solid #E5E7EB;
            padding: 20px 40px;
        }
        
        .topbar h2 {
            font-size: 24px;
            font-weight: 600;
            color: #111827;
        }
        
        .topbar .subtitle {
            font-size: 13px;
            color: #6B7280;
            margin-top: 4px;
        }
        
        .content-area {
            padding: 32px 40px;
        }
        
        .tab-content {
            display: none;
        }
        
        .tab-content.active {
            display: block;
        }
        
        /* KPI Cards */
        .kpi-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
            gap: 24px;
            margin-bottom: 32px;
        }
        
        .kpi-card {
            background: #FFFFFF;
            border: 1px solid #E5E7EB;
            padding: 24px;
            display: flex;
            flex-direction: column;
        }
        
        .kpi-card .label {
            font-size: 12px;
            font-weight: 600;
            color: #6B7280;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            margin-bottom: 8px;
        }
        
        .kpi-card .value {
            font-size: 36px;
            font-weight: 700;
            line-height: 1;
            margin-bottom: 8px;
        }
        
        .kpi-card .subtext {
            font-size: 13px;
            color: #6B7280;
        }
        
        .kpi-card.success .value {
            color: #059669;
        }
        
        .kpi-card.danger .value {
            color: #DC2626;
        }
        
        .kpi-card.primary .value {
            color: #0078D4;
        }
        
        .kpi-card.warning .value {
            color: #D97706;
        }
        
        /* Charts */
        .chart-row {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 24px;
            margin-bottom: 32px;
        }
        
        .chart-container {
            background: #FFFFFF;
            border: 1px solid #E5E7EB;
            padding: 24px;
            height: 350px;
            display: flex;
            flex-direction: column;
        }
        
        .chart-container canvas {
            max-height: 280px;
            flex: 1;
        }
        
        .chart-header {
            font-size: 16px;
            font-weight: 600;
            color: #111827;
            margin-bottom: 20px;
        }
        
        /* Tables */
        .table-container {
            background: #FFFFFF;
            border: 1px solid #E5E7EB;
            overflow: hidden;
        }
        
        .table-header {
            padding: 20px 24px;
            border-bottom: 1px solid #E5E7EB;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        
        .table-title {
            font-size: 16px;
            font-weight: 600;
            color: #111827;
        }
        
        table {
            width: 100%;
            border-collapse: collapse;
        }
        
        thead {
            background: #F9FAFB;
        }
        
        th {
            padding: 12px 24px;
            text-align: left;
            font-size: 11px;
            font-weight: 600;
            color: #6B7280;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            border-bottom: 1px solid #E5E7EB;
        }
        
        .column-filter {
            display: block;
            width: 100%;
            margin-top: 8px;
            padding: 6px 10px;
            font-size: 13px;
            color: #374151;
            background-color: #F9FAFB;
            border: 1px solid #D1D5DB;
            border-radius: 4px;
            text-transform: none;
            letter-spacing: normal;
            font-weight: 400;
            cursor: pointer;
            appearance: auto;
        }
        
        .column-filter:hover {
            border-color: #9CA3AF;
            background-color: #FFFFFF;
        }
        
        .column-filter:focus {
            outline: none;
            border-color: #2563EB;
            background-color: #FFFFFF;
            box-shadow: 0 0 0 3px rgba(37, 99, 235, 0.1);
        }
        
        td {
            padding: 16px 24px;
            border-bottom: 1px solid #F3F4F6;
            font-size: 14px;
        }
        
        tbody tr:hover {
            background: #F9FAFB;
        }
        
        /* Status Badges */
        .status-badge {
            display: inline-flex;
            align-items: center;
            padding: 4px 10px;
            font-size: 12px;
            font-weight: 600;
            border-radius: 4px;
            gap: 6px;
        }
        
        .status-badge.pass {
            background: #D1FAE5;
            color: #065F46;
        }
        
        .status-badge.fail {
            background: #FEE2E2;
            color: #991B1B;
        }
        
        .status-dot {
            width: 6px;
            height: 6px;
            border-radius: 50%;
        }
        
        .status-dot.pass {
            background: #10B981;
        }
        
        .status-dot.fail {
            background: #EF4444;
        }
        
        /* Filters */
        .filter-bar {
            display: flex;
            gap: 8px;
            margin-bottom: 16px;
        }
        
        .filter-btn {
            padding: 8px 16px;
            background: #FFFFFF;
            border: 1px solid #D1D5DB;
            color: #374151;
            font-size: 13px;
            font-weight: 500;
            cursor: pointer;
            transition: all 0.2s;
        }
        
        .filter-btn:hover {
            border-color: #0078D4;
            color: #0078D4;
        }
        
        .filter-btn.active {
            background: #0078D4;
            border-color: #0078D4;
            color: white;
        }
        
        /* Expandable Details */
        .details-link {
            color: #0078D4;
            cursor: pointer;
            font-size: 13px;
            font-weight: 500;
        }
        
        .details-link:hover {
            text-decoration: underline;
        }
        
        .details-panel {
            display: none;
            margin-top: 12px;
            padding: 16px;
            background: #F9FAFB;
            border-left: 2px solid #0078D4;
        }
        
        .details-panel.show {
            display: block;
        }
        
        .details-row {
            margin-bottom: 8px;
            font-size: 13px;
        }
        
        .details-row strong {
            color: #374151;
            margin-right: 8px;
        }
        
        .details-row pre {
            background: #FFFFFF;
            padding: 12px;
            border: 1px solid #E5E7EB;
            overflow-x: auto;
            font-size: 12px;
            margin-top: 8px;
        }
        
        .footer {
            background: #F9FAFB;
            border-top: 1px solid #E5E7EB;
            padding: 24px 40px;
            text-align: center;
            color: #6B7280;
            font-size: 13px;
        }
    </style>
</head>
<body>
    <div class="container">
        <!-- Sidebar Navigation -->
        <div class="sidebar">
            <div class="sidebar-header">
                <h1>Azure Auditor</h1>
                <p>Compliance Dashboard</p>
            </div>
            <div class="nav-menu">
                <div class="nav-item active" onclick="showTab('overview')">
                    <span class="nav-icon">📊</span>
                    <span>Overview</span>
                </div>
"@

        # Add category nav items
        foreach ($category in $categoriesData) {
            $categoryName = $category.Name
            $icon = switch ($categoryName) {
                'Compute' { '💻' }
                'Networking' { '🌐' }
                'Database' { '🗄️' }
                'Recovery' { '🔄' }
                'Storage' { '💾' }
                'Security' { '🔒' }
                default { '📦' }
            }
            $html += @"

                <div class="nav-item" onclick="showTab('$categoryName')">
                    <span class="nav-icon">$icon</span>
                    <span>$categoryName</span>
                </div>
"@
        }

        $html += @"

            </div>
        </div>

        
        <!-- Main Content Area -->
        <div class="main-content">
            <!-- Overview Tab -->
            <div id="overview" class="tab-content active">
                <div class="topbar">
                    <h2>Compliance Overview</h2>
                    <div class="subtitle">Generated: $(Get-Date -Format "MMM dd, yyyy 'at' HH:mm:ss")</div>
                </div>
                <div class="content-area">
                    <!-- KPI Cards -->
                    <div class="kpi-grid">
                        <div class="kpi-card primary">
                            <div class="label">Total Tests</div>
                            <div class="value">$totalTests</div>
                            <div class="subtext">Compliance Checks</div>
                        </div>
                        <div class="kpi-card success">
                            <div class="label">Passed</div>
                            <div class="value">$passedTests</div>
                            <div class="subtext">$passPercentage% Success Rate</div>
                        </div>
                        <div class="kpi-card danger">
                            <div class="label">Failed</div>
                            <div class="value">$failedTests</div>
                            <div class="subtext">Require Attention</div>
                        </div>
                        <div class="kpi-card warning">
                            <div class="label">Subscriptions</div>
                            <div class="value">$subscriptions</div>
                            <div class="subtext">Azure Subscriptions</div>
                        </div>
                    </div>
                    
                    <!-- Charts -->
                    <div class="chart-row">
                        <div class="chart-container">
                            <div class="chart-header">Overall Compliance Status</div>
                            <canvas id="overallChart"></canvas>
                        </div>
                        <div class="chart-container">
                            <div class="chart-header">Results by Category</div>
                            <canvas id="categoryChart"></canvas>
                        </div>
                    </div>
                    
                    <!-- Summary Table -->
                    <div class="table-container">
                        <div class="table-header">
                            <div class="table-title">Category Summary</div>
                        </div>
                        <table>
                <thead>
                    <tr>
                        <th>Category</th>
                        <th>SubCategory</th>
                        <th>Total Tests</th>
                        <th>Passed</th>
                        <th>Failed</th>
                        <th>Pass Rate</th>
                    </tr>
                </thead>
                <tbody>
"@

        # Add summary rows
        foreach ($subcat in $subcategoriesData) {
            $catName = $subcat.Group[0].Category
            $subcatName = $subcat.Group[0].SubCategory
            $total = $subcat.Count
            $passed = ($subcat.Group | Where-Object { $_.ResultStatus -eq 'Pass' }).Count
            $failed = ($subcat.Group | Where-Object { $_.ResultStatus -eq 'Fail' }).Count
            $rate = if ($total -gt 0) { [math]::Round(($passed / $total) * 100, 1) } else { 0 }
            
            $html += @"

                    <tr>
                        <td><strong>$catName</strong></td>
                        <td>$subcatName</td>
                        <td>$total</td>
                        <td style="color: #10b981; font-weight: bold;">$passed</td>
                        <td style="color: #ef4444; font-weight: bold;">$failed</td>
                        <td><strong>$rate%</strong></td>
                    </tr>
"@
        }

        $html += @"

                </tbody>
                        </table>
                    </div>
                </div>
            </div>
"@

        # Add category detail tabs
        foreach ($category in $categoriesData) {
            $categoryName = $category.Name
            $categoryResults = $category.Group
            
            $html += @"

        
            <!-- $categoryName Tab -->
            <div id="$categoryName" class="tab-content">
                <div class="topbar">
                    <h2>$categoryName Tests</h2>
                    <div class="subtitle">Detailed test results for $categoryName resources</div>
                </div>
                <div class="content-area">
                    <div class="filter-bar">
                        <button class="filter-btn active" onclick="filterResults('$categoryName', 'all')">All Results</button>
                        <button class="filter-btn" onclick="filterResults('$categoryName', 'pass')">Passed Only</button>
                        <button class="filter-btn" onclick="filterResults('$categoryName', 'fail')">Failed Only</button>
                    </div>
                    
                    <div class="table-container">
                        <div class="table-header">
                            <div class="table-title">Test Results</div>
                        </div>
                        <table id="${categoryName}Table" class="filterable-table">
                <thead>
                    <tr>
                        <th>
                            Resource Name
                            <select class="column-filter" data-column="0" onchange="filterTable('${categoryName}Table')">
                                <option value="">All</option>
                            </select>
                        </th>
                        <th>
                            Test
                            <select class="column-filter" data-column="1" onchange="filterTable('${categoryName}Table')">
                                <option value="">All</option>
                            </select>
                        </th>
                        <th>
                            Status
                            <select class="column-filter" data-column="2" onchange="syncStatusButtons('${categoryName}Table'); filterTable('${categoryName}Table')">
                                <option value="">All</option>
                            </select>
                        </th>
                        <th>
                            Subscription
                            <select class="column-filter" data-column="3" onchange="filterTable('${categoryName}Table')">
                                <option value="">All</option>
                            </select>
                        </th>
                        <th>Details</th>
                    </tr>
                </thead>
                <tbody>
"@

            $rowIndex = 0
            foreach ($result in $categoryResults) {
                $statusBadge = if ($result.ResultStatus -eq 'Pass') { 
                    "<span class='status-badge pass'><span class='status-dot pass'></span>Pass</span>" 
                } else { 
                    "<span class='status-badge fail'><span class='status-dot fail'></span>Fail</span>" 
                }
                
                $html += @"

                    <tr class="result-row" data-status="$($result.ResultStatus)">
                        <td><strong>$($result.ResourceName)</strong><br/><small style="color: #6b7280;">$($result.ResourceGroupName)</small></td>
                        <td><strong>$($result.TestName)</strong><br/><small style="color: #6b7280;">$($result.TestDescription)</small></td>
                        <td>$statusBadge</td>
                        <td><small style="color: #6b7280;">$($result.SubscriptionId)</small></td>
                        <td>
                            <span class="details-link" onclick="toggleDetails('${categoryName}_${rowIndex}')">View Details</span>
                            <div id="${categoryName}_${rowIndex}" class="details-panel">
                                <div class="details-row"><strong>Expected:</strong> $($result.ExpectedResult)</div>
                                <div class="details-row"><strong>Actual:</strong> $($result.ActualResult)</div>
                                <div class="details-row"><strong>Timestamp:</strong> $($result.TimeStamp)</div>
                                <div class="details-row">
                                    <strong>Raw Result:</strong>
                                    <pre>$($result.RawResult | ConvertTo-Json -Depth 3)</pre>
                                </div>
                            </div>
                        </td>
                    </tr>
"@
                $rowIndex++
            }

            $html += @"

                </tbody>
                        </table>
                    </div>
                </div>
            </div>
"@
        }

        # JavaScript for charts and interactivity
        $categoryLabels = ($categoriesData | ForEach-Object { "'$($_.Name)'" }) -join ','
        $categoryPassData = ($categoriesData | ForEach-Object { 
            ($_.Group | Where-Object { $_.ResultStatus -eq 'Pass' }).Count 
        }) -join ','
        $categoryFailData = ($categoriesData | ForEach-Object { 
            ($_.Group | Where-Object { $_.ResultStatus -eq 'Fail' }).Count 
        }) -join ','

        $html += @"


        
            <div class="footer">
                <p><strong>Azure Auditor</strong> | Well-Architected Framework Compliance Tool</p>
                <p>Report generated on $(Get-Date -Format "MMMM dd, yyyy 'at' HH:mm:ss")</p>
            </div>
        </div>
    </div>
    
    <script>
        // Navigation switching
        function showTab(tabName) {
            const navItems = document.querySelectorAll('.nav-item');
            const contents = document.querySelectorAll('.tab-content');
            
            navItems.forEach(item => item.classList.remove('active'));
            contents.forEach(content => content.classList.remove('active'));
            
            event.currentTarget.classList.add('active');
            document.getElementById(tabName).classList.add('active');
        }
        
        // Toggle details panel
        function toggleDetails(id) {
            const details = document.getElementById(id);
            details.classList.toggle('show');
        }
        
        // Filter results
        // Sync button states with Status dropdown
        function syncStatusButtons(tableId) {
            const table = document.getElementById(tableId);
            const statusDropdown = table.querySelector('thead .column-filter[data-column="2"]');
            const category = tableId.replace('Table', '');
            const filterBar = document.querySelector('#' + category + ' .filter-bar');
            if (!filterBar) return;
            
            const buttons = filterBar.querySelectorAll('.filter-btn');
            const statusValue = statusDropdown.value;
            
            buttons.forEach(btn => btn.classList.remove('active'));
            
            if (statusValue === '') {
                buttons[0].classList.add('active'); // All Results
            } else if (statusValue === 'Pass') {
                buttons[1].classList.add('active'); // Passed Only
            } else if (statusValue === 'Fail') {
                buttons[2].classList.add('active'); // Failed Only
            }
        }
        
        // Filter results by status buttons - updates the Status dropdown and triggers column filtering
        function filterResults(category, filter) {
            const table = document.getElementById(category + 'Table');
            const buttons = document.querySelector('#' + category + ' .filter-bar').querySelectorAll('.filter-btn');
            const statusDropdown = table.querySelector('thead .column-filter[data-column="2"]');
            
            // Update button active state
            buttons.forEach(btn => btn.classList.remove('active'));
            event.currentTarget.classList.add('active');
            
            // Update the Status dropdown to match button selection
            if (filter === 'all') {
                statusDropdown.value = '';
            } else if (filter === 'pass') {
                statusDropdown.value = 'Pass';
            } else if (filter === 'fail') {
                statusDropdown.value = 'Fail';
            }
            
            // Trigger the unified filter function that respects all column filters
            filterTable(category + 'Table');
        }
        
        // Overall Pass/Fail Chart
        const overallCtx = document.getElementById('overallChart').getContext('2d');
        new Chart(overallCtx, {
            type: 'doughnut',
            data: {
                labels: ['Passed', 'Failed'],
                datasets: [{
                    data: [$passedTests, $failedTests],
                    backgroundColor: ['#10b981', '#ef4444'],
                    borderWidth: 0
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        position: 'bottom',
                        labels: {
                            font: { size: 12 },
                            padding: 10
                        }
                    },
                    title: {
                        display: false
                    }
                }
            }
        });
        
        // Category Comparison Chart
        const categoryCtx = document.getElementById('categoryChart').getContext('2d');
        new Chart(categoryCtx, {
            type: 'bar',
            data: {
                labels: [$categoryLabels],
                datasets: [
                    {
                        label: 'Passed',
                        data: [$categoryPassData],
                        backgroundColor: '#10b981'
                    },
                    {
                        label: 'Failed',
                        data: [$categoryFailData],
                        backgroundColor: '#ef4444'
                    }
                ]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        position: 'bottom',
                        labels: {
                            font: { size: 12 },
                            padding: 10
                        }
                    },
                    title: {
                        display: false
                    }
                },
                scales: {
                    y: {
                        beginAtZero: true,
                        ticks: {
                            stepSize: 1,
                            font: { size: 11 }
                        }
                    },
                    x: {
                        ticks: {
                            font: { size: 11 }
                        }
                    }
                }
            }
        });
        
        // Populate filter dropdowns with unique values from table
        function populateFilters(tableId) {
            const table = document.getElementById(tableId);
            const rows = table.querySelectorAll('tbody tr');
            const filterSelects = table.querySelectorAll('thead .column-filter');
            
            filterSelects.forEach(select => {
                const columnIndex = parseInt(select.getAttribute('data-column'));
                const uniqueValues = new Set();
                
                // Collect unique values from this column
                rows.forEach(row => {
                    const cells = row.querySelectorAll('td');
                    if (cells.length > columnIndex) {
                        let cellText = cells[columnIndex].textContent.trim();
                        let displayText = cellText;
                        
                        // For Resource Name column, extract just the name from <strong> tag
                        if (columnIndex === 0) {
                            const strongTag = cells[columnIndex].querySelector('strong');
                            cellText = strongTag ? strongTag.textContent.trim() : cellText;
                            displayText = cellText;
                        }
                        // For Test column, extract name from <strong> and description from <small>
                        else if (columnIndex === 1) {
                            const strongTag = cells[columnIndex].querySelector('strong');
                            const smallTag = cells[columnIndex].querySelector('small');
                            const testName = strongTag ? strongTag.textContent.trim() : '';
                            const testDesc = smallTag ? smallTag.textContent.trim() : '';
                            cellText = testName; // Filter value (just test name)
                            displayText = testDesc ? testName + ' | ' + testDesc : testName; // Display with delimiter
                        }
                        // For Status column, extract just Pass/Fail text
                        else if (columnIndex === 2) {
                            cellText = cellText.includes('Pass') ? 'Pass' : 'Fail';
                            displayText = cellText;
                        }
                        // For Subscription column, extract from <small> tag
                        else if (columnIndex === 3) {
                            const smallTag = cells[columnIndex].querySelector('small');
                            cellText = smallTag ? smallTag.textContent.trim() : cellText;
                            displayText = cellText;
                        }
                        
                        uniqueValues.add(JSON.stringify({ value: cellText, display: displayText }));
                    }
                });
                
                // Sort values and populate dropdown
                const sortedValues = Array.from(uniqueValues).map(v => JSON.parse(v)).sort((a, b) => a.display.localeCompare(b.display));
                sortedValues.forEach(item => {
                    const option = document.createElement('option');
                    option.value = item.value;
                    option.textContent = item.display;
                    select.appendChild(option);
                });
            });
        }
        
        // Column filtering function - supports multiple simultaneous filters
        function filterTable(tableId) {
            const table = document.getElementById(tableId);
            const rows = table.querySelectorAll('tbody tr');
            const filterSelects = table.querySelectorAll('thead .column-filter');
            
            // Build filter criteria from all selects
            const filters = [];
            filterSelects.forEach(select => {
                const value = select.value.trim();
                const columnIndex = parseInt(select.getAttribute('data-column'));
                if (value) {
                    filters.push({ index: columnIndex, value: value });
                }
            });
            
            // Apply all filters to each row
            rows.forEach(row => {
                const cells = row.querySelectorAll('td');
                let showRow = true;
                
                // Check each filter
                for (const filter of filters) {
                    if (cells.length > filter.index) {
                        let cellText = cells[filter.index].textContent.trim();
                        
                        // For Resource Name column, extract from <strong> tag
                        if (filter.index === 0) {
                            const strongTag = cells[filter.index].querySelector('strong');
                            cellText = strongTag ? strongTag.textContent.trim() : cellText;
                        }
                        // For Test column, extract from <strong> tag
                        else if (filter.index === 1) {
                            const strongTag = cells[filter.index].querySelector('strong');
                            cellText = strongTag ? strongTag.textContent.trim() : cellText;
                        }
                        // For Status column, extract Pass/Fail
                        else if (filter.index === 2) {
                            cellText = cellText.includes('Pass') ? 'Pass' : 'Fail';
                        }
                        // For Subscription column, extract from <small> tag
                        else if (filter.index === 3) {
                            const smallTag = cells[filter.index].querySelector('small');
                            cellText = smallTag ? smallTag.textContent.trim() : cellText;
                        }
                        
                        if (cellText !== filter.value) {
                            showRow = false;
                            break;
                        }
                    }
                }
                
                row.style.display = showRow ? '' : 'none';
            });
        }
        
        // Initialize all filterable tables on page load
        document.addEventListener('DOMContentLoaded', function() {
            document.querySelectorAll('.filterable-table').forEach(table => {
                populateFilters(table.id);
            });
        });
    </script>
</body>
</html>
"@

        # Save HTML to file
        $html | Out-File -FilePath $OutputPath -Encoding UTF8
        
        Write-Verbose "Report saved to: $OutputPath"
        
        if ($OpenInBrowser) {
            Start-Process $OutputPath
        }
        
        return $OutputPath
    }
}

