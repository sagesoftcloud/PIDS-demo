let rawData = [];
let filteredData = [];
let charts = {};

document.getElementById('fileUpload').addEventListener('change', handleFileUpload);
document.getElementById('downloadChart').addEventListener('click', downloadCharts);
document.getElementById('generateReport').addEventListener('click', generateReport);

function handleFileUpload(e) {
    const file = e.target.files[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = function(e) {
        try {
            let jsonData;
            let sheetNames = [];
            
            if (file.name.endsWith('.csv')) {
                // Parse CSV
                const text = e.target.result;
                const lines = text.split('\n').filter(line => line.trim());
                const headers = lines[0].split(',').map(h => h.trim());
                
                jsonData = lines.slice(1).map(line => {
                    const values = line.split(',').map(v => v.trim());
                    const obj = {};
                    headers.forEach((header, i) => {
                        obj[header] = values[i] || '';
                    });
                    return obj;
                });
            } else {
                // Parse Excel
                const data = new Uint8Array(e.target.result);
                const workbook = XLSX.read(data, { type: 'array' });
                sheetNames = workbook.SheetNames;
                
                console.log('Sheet names:', sheetNames);
                
                // Process all sheets
                jsonData = [];
                sheetNames.forEach(sheetName => {
                    const sheet = workbook.Sheets[sheetName];
                    const sheetData = XLSX.utils.sheet_to_json(sheet);
                    
                    // Add sheet name as team member if not in data
                    sheetData.forEach(row => {
                        row._sheetName = sheetName;
                    });
                    
                    jsonData = jsonData.concat(sheetData);
                });
            }
            
            console.log('Total rows parsed:', jsonData.length);
            console.log('First 3 rows:', jsonData.slice(0, 3));
            
            if (!jsonData || jsonData.length === 0) {
                alert('No data found in file. Please check the file format.');
                return;
            }
            
            rawData = processData(jsonData);
            filteredData = [...rawData];
            
            console.log('Total processed rows:', rawData.length);
            console.log('First 3 processed:', rawData.slice(0, 3));
            
            renderDashboard();
        } catch (error) {
            console.error('Error processing file:', error);
            alert('Error reading file: ' + error.message);
        }
    };
    
    if (file.name.endsWith('.csv')) {
        reader.readAsText(file);
    } else {
        reader.readAsArrayBuffer(file);
    }
}

function processData(data) {
    if (!data || data.length === 0) return [];
    
    console.log('=== PROCESSING DATA ===');
    console.log('Total rows:', data.length);
    
    const columns = Object.keys(data[0]);
    console.log('Detected columns:', columns);
    
    return data.map((row, index) => {
        // Use sheet name as team member
        const teamMember = row._sheetName || 'Unknown';
        
        // Use exact column names from your Excel
        const date = row['Date'] || '';
        const project = row['Project/Client'] || '';
        const description = row['Description'] || '';
        const billableText = String(row['Billable/Non-Billable'] || '').trim();
        const hours = parseFloat(row['Total hrs'] || 0);
        
        // Determine billable status
        const billable = billableText === 'Billable' ? 'Yes' : 'No';
        
        // Auto-detect department from sheet name
        const department = teamMember.toLowerCase().includes('technical') ? 'Technical Team' :
                          teamMember.toLowerCase().includes('pre-sales') || teamMember.toLowerCase().includes('presales') ? 'Pre-sales Team' :
                          teamMember.toLowerCase().includes('project') || teamMember.toLowerCase().includes('pm') ? 'Project Management Unit Team' : 
                          'General';
        
        if (index < 3) {
            console.log(`Row ${index + 1}:`, {
                teamMember, department, date, project, description, hours, billable
            });
        }
        
        return {
            teamMember: String(teamMember),
            department: String(department),
            project: String(project),
            description: String(description),
            hours: hours,
            billable: billable,
            category: billableText
        };
    });
}

function renderDashboard() {
    document.getElementById('dashboard').style.display = 'block';
    filteredData = [...rawData];
    
    const billableHours = filteredData
        .filter(item => item.billable.toLowerCase() === 'yes' || item.billable.toLowerCase() === 'billable')
        .reduce((sum, item) => sum + item.hours, 0);
    
    const nonBillableHours = filteredData
        .filter(item => item.billable.toLowerCase() === 'no' || item.billable.toLowerCase() === 'non-billable')
        .reduce((sum, item) => sum + item.hours, 0);
    
    const totalHours = billableHours + nonBillableHours;
    const utilizationRate = totalHours > 0 ? (billableHours / totalHours * 100) : 0;
    
    document.getElementById('totalHours').textContent = totalHours.toFixed(2);
    document.getElementById('billableHours').textContent = billableHours.toFixed(2);
    document.getElementById('nonBillableHours').textContent = nonBillableHours.toFixed(2);
    document.getElementById('utilizationRate').textContent = utilizationRate.toFixed(1) + '%';
    
    renderCharts(billableHours, nonBillableHours);
    renderUtilizationTable();
    renderSummaryTable();
    renderDetailsTable();
}

function renderCharts(billableHours, nonBillableHours) {
    // Destroy existing charts
    if (charts.hoursChart) charts.hoursChart.destroy();
    if (charts.projectChart) charts.projectChart.destroy();
    
    // Billable vs Non-Billable Chart
    const ctx1 = document.getElementById('hoursChart').getContext('2d');
    charts.hoursChart = new Chart(ctx1, {
        type: 'doughnut',
        data: {
            labels: ['Billable Hours', 'Non-Billable Hours'],
            datasets: [{
                data: [billableHours, nonBillableHours],
                backgroundColor: ['#38ef7d', '#ff6a00'],
                borderWidth: 2,
                borderColor: '#fff'
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: true,
            plugins: {
                legend: { position: 'bottom' }
            }
        }
    });
    
    // Project Breakdown Chart
    const projectData = {};
    filteredData.forEach(item => {
        if (!projectData[item.project]) {
            projectData[item.project] = { billable: 0, nonBillable: 0 };
        }
        if (item.billable.toLowerCase() === 'yes' || item.billable.toLowerCase() === 'billable') {
            projectData[item.project].billable += item.hours;
        } else {
            projectData[item.project].nonBillable += item.hours;
        }
    });
    
    const projects = Object.keys(projectData);
    const billableByProject = projects.map(p => projectData[p].billable);
    const nonBillableByProject = projects.map(p => projectData[p].nonBillable);
    
    const ctx2 = document.getElementById('projectChart').getContext('2d');
    charts.projectChart = new Chart(ctx2, {
        type: 'bar',
        data: {
            labels: projects,
            datasets: [
                {
                    label: 'Billable Hours',
                    data: billableByProject,
                    backgroundColor: '#38ef7d'
                },
                {
                    label: 'Non-Billable Hours',
                    data: nonBillableByProject,
                    backgroundColor: '#ff6a00'
                }
            ]
        },
        options: {
            responsive: true,
            maintainAspectRatio: true,
            scales: {
                x: { stacked: true },
                y: { stacked: true, beginAtZero: true }
            },
            plugins: {
                legend: { position: 'bottom' }
            }
        }
    });
}

function renderUtilizationTable() {
    const tbody = document.querySelector('#utilizationTable tbody');
    tbody.innerHTML = '';
    
    const memberStats = {};
    filteredData.forEach(item => {
        if (!memberStats[item.teamMember]) {
            memberStats[item.teamMember] = {
                department: item.department,
                total: 0,
                billable: 0,
                nonBillable: 0
            };
        }
        memberStats[item.teamMember].total += item.hours;
        if (item.billable.toLowerCase() === 'yes' || item.billable.toLowerCase() === 'billable') {
            memberStats[item.teamMember].billable += item.hours;
        } else {
            memberStats[item.teamMember].nonBillable += item.hours;
        }
    });
    
    Object.entries(memberStats).forEach(([member, stats]) => {
        const utilization = stats.total > 0 ? (stats.billable / stats.total * 100) : 0;
        const row = tbody.insertRow();
        row.innerHTML = `
            <td>${member}</td>
            <td>${stats.department}</td>
            <td>${stats.total.toFixed(2)}</td>
            <td>${stats.billable.toFixed(2)}</td>
            <td>${stats.nonBillable.toFixed(2)}</td>
            <td><strong>${utilization.toFixed(1)}%</strong></td>
        `;
    });
}

function renderSummaryTable() {
    const tbody = document.querySelector('#summaryTable tbody');
    tbody.innerHTML = '';
    
    const summary = {};
    filteredData.forEach(item => {
        const key = `${item.category || 'General'}_${item.project}`;
        if (!summary[key]) {
            summary[key] = {
                category: item.category || 'General',
                project: item.project,
                billable: 0,
                nonBillable: 0
            };
        }
        if (item.billable.toLowerCase() === 'yes' || item.billable.toLowerCase() === 'billable') {
            summary[key].billable += item.hours;
        } else {
            summary[key].nonBillable += item.hours;
        }
    });
    
    Object.values(summary).forEach(item => {
        const row = tbody.insertRow();
        row.innerHTML = `
            <td>${item.category}</td>
            <td>${item.project}</td>
            <td>${item.billable.toFixed(2)}</td>
            <td>${item.nonBillable.toFixed(2)}</td>
            <td>${(item.billable + item.nonBillable).toFixed(2)}</td>
        `;
    });
}

function renderDetailsTable() {
    const tbody = document.querySelector('#detailsTable tbody');
    tbody.innerHTML = '';
    
    filteredData.forEach(item => {
        const row = tbody.insertRow();
        row.innerHTML = `
            <td>${item.teamMember}</td>
            <td>${item.description}</td>
            <td>${item.project}</td>
            <td>${item.hours.toFixed(2)}</td>
            <td>${item.billable}</td>
        `;
    });
}

function downloadCharts() {
    const chartsContainer = document.createElement('div');
    chartsContainer.style.background = 'white';
    chartsContainer.style.padding = '20px';
    
    const hoursCanvas = document.getElementById('hoursChart');
    const projectCanvas = document.getElementById('projectChart');
    
    chartsContainer.appendChild(hoursCanvas.cloneNode(true));
    chartsContainer.appendChild(projectCanvas.cloneNode(true));
    
    html2canvas(document.querySelector('.chart-section')).then(canvas => {
        const link = document.createElement('a');
        link.download = `timesheet-charts-${new Date().toISOString().split('T')[0]}.png`;
        link.href = canvas.toDataURL();
        link.click();
    });
}

function generateReport() {
    window.print();
}
