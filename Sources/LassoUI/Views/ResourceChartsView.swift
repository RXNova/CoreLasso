import SwiftUI
import Charts
import LassoCore
import LassoData

// MARK: - Resource Charts Card

public struct ResourceChartsView: View {

    @State private var chartsVM: OverviewChartsViewModel

    private let runningContainers: [ContainerInfo]
    private let volumes: [CLIVolumeEntry]

    public init(engine: any LassoContainerEngine, runningContainers: [ContainerInfo], volumes: [CLIVolumeEntry]) {
        self.runningContainers = runningContainers
        self.volumes = volumes
        _chartsVM = State(initialValue: OverviewChartsViewModel(engine: engine))
    }

    public var body: some View {
        OverviewSectionCard(title: "Resource Usage", icon: "chart.bar.fill") {
            if chartsVM.isLoading {
                HStack {
                    Spacer()
                    ProgressView("Fetching stats…").controlSize(.small)
                        .foregroundStyle(LassoColors.antTextSecondary)
                    Spacer()
                }
                .padding(LassoSpacing.lg.rawValue)
            } else if chartsVM.memoryStats.isEmpty && chartsVM.cpuStats.isEmpty && chartsVM.volumeStats.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "chart.bar")
                            .font(.title2)
                            .foregroundStyle(LassoColors.antTextDisabled)
                        Text("No data — start a container to see resource usage.")
                            .font(.caption)
                            .foregroundStyle(LassoColors.antTextSecondary)
                    }
                    Spacer()
                }
                .padding(LassoSpacing.lg.rawValue)
            } else {
                VStack(spacing: 0) {
                    // Memory + CPU side by side
                    if !chartsVM.memoryStats.isEmpty || !chartsVM.cpuStats.isEmpty {
                        HStack(alignment: .top, spacing: 0) {
                            if !chartsVM.memoryStats.isEmpty {
                                chartSection("Memory Usage", trailingDivider: !chartsVM.cpuStats.isEmpty) {
                                    memoryChart
                                }
                            }
                            if !chartsVM.cpuStats.isEmpty {
                                chartSection("CPU Usage", trailingDivider: false) {
                                    cpuChart
                                }
                            }
                        }
                        if !chartsVM.volumeStats.isEmpty { Divider() }
                    }
                    if !chartsVM.volumeStats.isEmpty {
                        chartSection("Volume Storage", trailingDivider: false) {
                            volumeChart
                        }
                    }
                }
            }
        }
        .task(id: runningContainers.map(\.id).sorted().joined()) {
            await chartsVM.load(runningContainers: runningContainers, volumes: volumes)
        }
    }

    // MARK: - Chart Sections

    private func chartSection<C: View>(_ title: String, trailingDivider: Bool, @ViewBuilder content: () -> C) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: LassoSpacing.sm.rawValue) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LassoColors.antTextSecondary)
                    .padding(.horizontal, LassoSpacing.md.rawValue)
                    .padding(.top, LassoSpacing.md.rawValue)
                content()
                    .padding(.horizontal, LassoSpacing.md.rawValue)
                    .padding(.bottom, LassoSpacing.md.rawValue)
            }
            .frame(maxWidth: .infinity)
            if trailingDivider { Divider() }
        }
    }

    // MARK: - Memory Chart

    private var memoryChart: some View {
        Chart(chartsVM.memoryStats) { stat in
            BarMark(
                x: .value("Used %", stat.percent * 100),
                y: .value("Container", stat.name)
            )
            .foregroundStyle(
                stat.percent > 0.85 ? LassoColors.antError :
                stat.percent > 0.65 ? LassoColors.antWarning :
                LassoColors.antBlue
            )
            .cornerRadius(4)
            .annotation(position: .trailing, alignment: .leading) {
                Text(formatBytes(stat.usedBytes))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(LassoColors.antTextSecondary)
            }
        }
        .chartXScale(domain: 0...100)
        .chartXAxis {
            AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                AxisGridLine().foregroundStyle(LassoColors.antBorder)
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text("\(Int(v))%")
                            .font(.caption2)
                            .foregroundStyle(LassoColors.antTextDisabled)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks { _ in
                AxisValueLabel()
                    .font(.caption)
                    .foregroundStyle(LassoColors.antTextPrimary)
            }
        }
        .frame(height: CGFloat(max(60, chartsVM.memoryStats.count * 36)))
    }

    // MARK: - CPU Chart

    private var cpuChart: some View {
        Chart(chartsVM.cpuStats) { stat in
            BarMark(
                x: .value("CPU %", stat.percent),
                y: .value("Container", stat.name)
            )
            .foregroundStyle(
                stat.percent > 85 ? LassoColors.antError :
                stat.percent > 60 ? LassoColors.antWarning :
                LassoColors.antSuccess
            )
            .cornerRadius(4)
            .annotation(position: .trailing, alignment: .leading) {
                Text(String(format: "%.1f%%", stat.percent))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(LassoColors.antTextSecondary)
            }
        }
        .chartXScale(domain: 0...100)
        .chartXAxis {
            AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                AxisGridLine().foregroundStyle(LassoColors.antBorder)
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text("\(Int(v))%")
                            .font(.caption2)
                            .foregroundStyle(LassoColors.antTextDisabled)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks { _ in
                AxisValueLabel()
                    .font(.caption)
                    .foregroundStyle(LassoColors.antTextPrimary)
            }
        }
        .frame(height: CGFloat(max(60, chartsVM.cpuStats.count * 36)))
    }

    // MARK: - Volume Chart

    private var volumeChart: some View {
        let maxBytes = chartsVM.volumeStats.first?.bytes ?? 1
        return Chart(chartsVM.volumeStats) { stat in
            BarMark(
                x: .value("Size", stat.bytes),
                y: .value("Volume", stat.name)
            )
            .foregroundStyle(Color.orange)
            .cornerRadius(4)
            .annotation(position: .trailing, alignment: .leading) {
                Text(formatBytes(stat.bytes))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(LassoColors.antTextSecondary)
            }
        }
        .chartXScale(domain: 0...Double(maxBytes) * 1.15)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(LassoColors.antBorder)
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(formatBytes(UInt64(v)))
                            .font(.caption2)
                            .foregroundStyle(LassoColors.antTextDisabled)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks { _ in
                AxisValueLabel()
                    .font(.caption)
                    .foregroundStyle(LassoColors.antTextPrimary)
            }
        }
        .frame(height: CGFloat(max(60, chartsVM.volumeStats.count * 36)))
    }

    // MARK: - Formatters

    private func formatBytes(_ bytes: UInt64) -> String {
        let kb = Double(bytes) / 1024
        let mb = kb / 1024
        let gb = mb / 1024
        if gb >= 1   { return String(format: "%.1f GB", gb) }
        if mb >= 1   { return String(format: "%.1f MB", mb) }
        if kb >= 1   { return String(format: "%.1f KB", kb) }
        return "\(bytes) B"
    }
}
