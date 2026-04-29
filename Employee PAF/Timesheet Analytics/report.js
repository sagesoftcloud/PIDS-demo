let charts = {};

document.getElementById('fileUpload').addEventListener('change', handleFileUpload);

function handleFileUpload(e) {
    const file = e.target.files[0];
    if (!file) return;

    console.log('File selected:', file.name);

    const reader = new FileReader();
    reader.onload = function(e) {
        try {
            const data = new Uint8Array(e.target.result);
            const workbook = XLSX.read(data, { type: 'array' });
            
            console.log('Sheets found:', workbook.SheetNames);
            
            // Process all sheets
            const teamData = [];
            workbook.SheetNames.forEach(sheetName => {
                const sheet = workbook.Sheets[sheetName];
                
                // Get the range and read as array first to find header row
                const range = XLSX.utils.decode_range(sheet['!ref']);
                let headerRow = -1;
                
                // Find the row with "Date" or "Project/Client" header by checking multiple columns
                for (let row = range.s.r; row <= Math.min(range.s.r + 10, range.e.r); row++) {
                    // Check columns A through E for header indicators
                    for (let col = 0; col <= 4; col++) {
                        const cellAddress = XLSX.utils.encode_cell({ r: row, c: col });
                        const cell = sheet[cellAddress];
                        if (cell) {
                            const cellValue = String(cell.v).toLowerCase();
                            if (cellValue.includes('date') || cellValue.includes('project') || cellValue.includes('description')) {
                                headerRow = row;
                                break;
                            }
                        }
                    }
                    if (headerRow >= 0) break;
                }
                
                console.log(`Sheet "${sheetName}" header found at row ${headerRow}`);
                
                // Read data starting from header row
                const rows = XLSX.utils.sheet_to_json(sheet, { 
                    range: headerRow >= 0 ? headerRow : 0,
                    defval: '',
                    raw: false  // Convert dates and numbers to strings for easier handling
                });
                
                console.log(`Sheet "${sheetName}" has ${rows.length} rows`);
                
                if (rows.length > 0) {
                    console.log(`First row in "${sheetName}":`, rows[0]);
                    console.log('Available columns:', Object.keys(rows[0]));
                    console.log('First 3 rows:', rows.slice(0, 3));
                }
                
                // Filter and process valid data rows
                const tasks = [];
                
                // Find the actual column names (they might vary)
                const columns = rows.length > 0 ? Object.keys(rows[0]) : [];
                const dateCol = columns.find(c => c.toLowerCase().includes('date')) || 'Date';
                const projectCol = columns.find(c => c.toLowerCase().includes('project') || c.toLowerCase().includes('client')) || 'Project/Client';
                const descCol = columns.find(c => c.toLowerCase().includes('description') || c.toLowerCase().includes('task')) || 'Description';
                const hoursCol = columns.find(c => c.toLowerCase().includes('hrs') || c.toLowerCase().includes('hours')) || 'Total hrs';
                const billableCol = columns.find(c => c.toLowerCase().includes('billable')) || 'Billable/Non-Billable';
                
                console.log('Detected columns:', { dateCol, projectCol, descCol, hoursCol, billableCol });
                
                rows.forEach((row, index) => {
                    const project = String(row[projectCol] || '').trim();
                    const hoursStr = String(row[hoursCol] || '0').trim();
                    const hours = parseFloat(hoursStr) || 0;
                    const billableText = String(row[billableCol] || '').trim();
                    
                    if (index < 3) {
                        console.log(`Row ${index + 1}:`, {
                            project: project,
                            hours: hours,
                            billable: billableText,
                            rawHours: hoursStr
                        });
                    }
                    
                    // Skip if project is empty or looks like a header/week marker
                    if (!project || 
                        project.toUpperCase().includes('WEEK') || 
                        project === 'Project/Client' ||
                        project === projectCol) {
                        return;
                    }
                    
                    // Must have hours > 0
                    if (hours > 0) {
                        tasks.push({
                            date: String(row[dateCol] || '').trim(),
                            project: project,
                            description: String(row[descCol] || '').trim(),
                            hours: hours,
                            billable: billableText.toLowerCase() === 'billable' || billableText.toLowerCase() === 'yes'
                        });
                    }
                });
                
                console.log(`Sheet "${sheetName}" processed ${tasks.length} valid tasks`);
                
                if (tasks.length > 0) {
                    teamData.push({
                        name: sheetName,
                        tasks: tasks
                    });
                }
            });
            
            console.log('Total team members:', teamData.length);
            
            if (teamData.length === 0) {
                alert('No valid data found. Make sure your Excel has a row with headers: Date, Project/Client, Description, Billable/Non-Billable, Total hrs');
                return;
            }
            
            processAndRender(teamData);
        } catch (error) {
            console.error('Error:', error);
            alert('Error reading file: ' + error.message);
        }
    };
    reader.readAsArrayBuffer(file);
}

function processAndRender(teamData) {
    // Get title and date from inputs
    const title = document.getElementById('reportTitle').value || 'Weekly Utilization Report';
    const dateRange = document.getElementById('dateRange').value || 'Date Range Not Specified';
    
    // Update header
    document.getElementById('reportHeader').textContent = `📊 ${title}`;
    document.getElementById('reportSubtitle').textContent = `Performance Report | ${dateRange}`;
    
    // Calculate stats for each member
    const members = teamData.map(member => {
        const billable = member.tasks.filter(t => t.billable).reduce((sum, t) => sum + t.hours, 0);
        const nonBillable = member.tasks.filter(t => !t.billable).reduce((sum, t) => sum + t.hours, 0);
        const total = billable + nonBillable;
        const utilization = total > 0 ? (billable / total * 100) : 0;
        
        return {
            name: member.name,
            tasks: member.tasks,
            billable: billable,
            nonBillable: nonBillable,
            total: total,
            utilization: utilization
        };
    });
    
    // Calculate totals
    const totalBillable = members.reduce((sum, m) => sum + m.billable, 0);
    const totalNonBillable = members.reduce((sum, m) => sum + m.nonBillable, 0);
    const avgUtil = members.length > 0 ? (members.reduce((sum, m) => sum + m.utilization, 0) / members.length) : 0;
    
    // Update stats
    document.getElementById('avgUtil').textContent = avgUtil.toFixed(1) + '%';
    document.getElementById('totalBillable').textContent = totalBillable.toFixed(1);
    document.getElementById('totalNonBillable').textContent = totalNonBillable.toFixed(1);
    document.getElementById('teamCount').textContent = members.length;
    
    // Show dashboard
    document.getElementById('dashboard').style.display = 'block';
    
    // Render all sections
    renderMemberDetails(members);
    renderCharts(members, totalBillable, totalNonBillable);
    renderTables(members);
}

function renderMemberDetails(members) {
    const detailsDiv = document.getElementById('memberDetails');
    detailsDiv.innerHTML = '';
    
    members.forEach(member => {
        const section = document.createElement('div');
        section.className = 'member-section';
        
        const tasksHTML = member.tasks.map(task => `
            <div class="task-row">
                <div>${task.date}</div>
                <div><strong>${task.project}</strong></div>
                <div>${task.description}</div>
                <div>${task.hours}h</div>
                <div><span class="billable-badge ${task.billable ? 'billable-yes' : 'billable-no'}">${task.billable ? 'Billable' : 'Non-Billable'}</span></div>
            </div>
        `).join('');
        
        section.innerHTML = `
            <div class="member-name">${member.name}</div>
            <div class="task-row task-header">
                <div>Date</div>
                <div>Project</div>
                <div>Description</div>
                <div>Hours</div>
                <div>Type</div>
            </div>
            ${tasksHTML}
            <div style="margin-top: 15px; padding-top: 15px; border-top: 2px solid #2a5298; font-weight: bold;">
                Total: ${member.billable.toFixed(1)}h Billable + ${member.nonBillable.toFixed(1)}h Non-Billable = ${member.total.toFixed(1)}h (${member.utilization.toFixed(1)}% Utilization)
            </div>
        `;
        detailsDiv.appendChild(section);
    });
}

function renderCharts(members, totalBillable, totalNonBillable) {
    // Destroy existing charts
    Object.values(charts).forEach(chart => chart.destroy());
    charts = {};
    
    // Color palette
    const colors = [
        'rgba(42, 82, 152, 0.8)',   // Blue
        'rgba(30, 60, 114, 0.8)',   // Dark Blue
        'rgba(102, 126, 234, 0.8)', // Light Blue
        'rgba(118, 75, 162, 0.8)',  // Purple
        'rgba(56, 239, 125, 0.8)',  // Green
        'rgba(255, 106, 0, 0.8)',   // Orange
        'rgba(238, 9, 121, 0.8)',   // Pink
        'rgba(245, 87, 108, 0.8)'   // Red
    ];
    
    // Utilization Chart
    charts.utilization = new Chart(document.getElementById('utilizationChart'), {
        type: 'bar',
        data: {
            labels: members.map(m => m.name),
            datasets: [{
                label: 'Utilization %',
                data: members.map(m => m.utilization),
                backgroundColor: members.map((_, i) => colors[i % colors.length]),
                borderColor: members.map((_, i) => colors[i % colors.length].replace('0.8', '1')),
                borderWidth: 2
            }]
        },
        options: {
            responsive: true,
            scales: { y: { beginAtZero: true, max: 100 } },
            plugins: { legend: { display: false } }
        }
    });
    
    // Hours Doughnut Chart with percentages
    const total = totalBillable + totalNonBillable;
    const billablePercent = ((totalBillable / total) * 100).toFixed(1);
    const nonBillablePercent = ((totalNonBillable / total) * 100).toFixed(1);
    
    charts.hours = new Chart(document.getElementById('hoursChart'), {
        type: 'doughnut',
        data: {
            labels: ['Billable Hours', 'Non-Billable Hours'],
            datasets: [{
                data: [totalBillable, totalNonBillable],
                backgroundColor: ['rgba(56, 239, 125, 0.8)', 'rgba(255, 106, 0, 0.8)'],
                borderWidth: 2,
                borderColor: '#fff'
            }]
        },
        options: {
            responsive: true,
            plugins: {
                legend: {
                    position: 'bottom'
                },
                tooltip: {
                    callbacks: {
                        label: function(context) {
                            const label = context.label || '';
                            const value = context.parsed;
                            const percent = ((value / total) * 100).toFixed(1);
                            return `${label}: ${value}h (${percent}%)`;
                        }
                    }
                },
                datalabels: {
                    color: '#fff',
                    font: {
                        weight: 'bold',
                        size: 16
                    },
                    formatter: function(value, context) {
                        const percent = ((value / total) * 100).toFixed(1);
                        return percent + '%';
                    }
                }
            }
        },
        plugins: [{
            id: 'textCenter',
            beforeDraw: function(chart) {
                const width = chart.width;
                const height = chart.height;
                const ctx = chart.ctx;
                ctx.restore();
                
                const fontSize = (height / 114).toFixed(2);
                ctx.font = fontSize + "em sans-serif";
                ctx.textBaseline = "middle";
                ctx.fillStyle = "#333";
                
                const text = `${billablePercent}% Billable`;
                const textX = Math.round((width - ctx.measureText(text).width) / 2);
                const textY = height / 2;
                
                ctx.fillText(text, textX, textY);
                ctx.save();
            }
        }]
    });
    
    // Distribution Chart with multiple colors
    charts.distribution = new Chart(document.getElementById('distributionChart'), {
        type: 'bar',
        data: {
            labels: members.map(m => m.name),
            datasets: [
                {
                    label: 'Billable',
                    data: members.map(m => m.billable),
                    backgroundColor: members.map((_, i) => colors[i % colors.length])
                },
                {
                    label: 'Non-Billable',
                    data: members.map(m => m.nonBillable),
                    backgroundColor: members.map((_, i) => colors[(i + 1) % colors.length])
                }
            ]
        },
        options: {
            responsive: true,
            scales: { x: { stacked: true }, y: { stacked: true, beginAtZero: true } }
        }
    });
}

function renderTables(members) {
    // Billable Hours Table
    const billableTable = document.querySelector('#billableTable tbody');
    billableTable.innerHTML = members.map(member => {
        const billablePercent = ((member.billable / 40) * 100).toFixed(1);
        return `
            <tr>
                <td><strong>${member.name}</strong></td>
                <td>${member.billable.toFixed(1)}h</td>
                <td>${billablePercent}%</td>
            </tr>
        `;
    }).join('');
    
    // Non-Billable Hours Table
    const nonBillableTable = document.querySelector('#nonBillableTable tbody');
    nonBillableTable.innerHTML = members.map(member => {
        const nonBillablePercent = ((member.nonBillable / 40) * 100).toFixed(1);
        return `
            <tr>
                <td><strong>${member.name}</strong></td>
                <td>${member.nonBillable.toFixed(1)}h</td>
                <td>${nonBillablePercent}%</td>
            </tr>
        `;
    }).join('');
    
    // Summary Table
    const summaryTable = document.querySelector('#summaryTable tbody');
    summaryTable.innerHTML = members.map(member => `
        <tr>
            <td><strong>${member.name}</strong></td>
            <td>${member.billable.toFixed(1)}h</td>
            <td>${member.nonBillable.toFixed(1)}h</td>
            <td>${member.total.toFixed(1)}h</td>
            <td>
                <div class="util-bar">
                    <div class="util-fill" style="width: ${member.utilization}%">${member.utilization.toFixed(1)}%</div>
                </div>
            </td>
        </tr>
    `).join('');
}
