# Timesheet Analytics Dashboard

A web-based application for analyzing employee timesheet data with interactive charts and reports.

## Features

- **Excel File Upload**: Upload .xlsx or .xls files containing timesheet data
- **Department Filtering**: Filter data by Technical Team, Pre-sales Team, or Project Management Unit Team
- **Interactive Charts**: 
  - Doughnut chart for billable vs non-billable hours
  - Stacked bar chart for project breakdown
- **Summary Tables**: 
  - Billable/Non-billable summary by category and project
  - Detailed team member descriptions
- **Export Options**:
  - Download charts as images
  - Generate print-ready reports

## Usage

1. Open `index.html` in a web browser
2. Click "Upload Excel File" and select your timesheet file
3. Use the department dropdown to filter data
4. View charts and tables
5. Export charts or generate reports as needed

## Excel File Format

Your Excel file should contain the following columns:
- Team Member / Employee / Name
- Department / Team
- Project / Client / Project/Client
- Description / Task
- Hours / Total Hours
- Billable / Type (values: "Yes", "No", "Billable", "Non-Billable")
- Category (optional)

## Color Scheme

Based on Sagesoft Cloud branding:
- Primary: #1e3c72 (Deep Blue)
- Secondary: #2a5298 (Medium Blue)
- Billable: #38ef7d (Green)
- Non-Billable: #ff6a00 (Orange)

## Technologies Used

- HTML5
- CSS3
- JavaScript (ES6+)
- Chart.js (for charts)
- SheetJS (for Excel parsing)
- html2canvas (for chart export)
- jsPDF (for PDF generation)

## Browser Compatibility

Works on all modern browsers (Chrome, Firefox, Safari, Edge)
