import SwiftUI

struct HistoryView: View {
    @State private var sessions: [AttendanceSession] = []
    @State private var isLoading = true
    @State private var selectedPeriod = Period.week

    enum Period: String, CaseIterable {
        case week = "This Week"
        case month = "This Month"
        case all = "All"
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Period Picker
                    Picker("Period", selection: $selectedPeriod) {
                        ForEach(Period.allCases, id: \.self) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding()

                    // Summary
                    summaryRow

                    if isLoading {
                        Spacer()
                        ProgressView().tint(.white)
                        Spacer()
                    } else if filteredSessions.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "clock")
                                .font(.system(size: 48))
                                .foregroundColor(.gray)
                            Text("No attendance records")
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    } else {
                        List {
                            ForEach(groupedByDate, id: \.0) { date, daySessions in
                                Section {
                                    ForEach(daySessions, id: \.id) { session in
                                        sessionRow(session)
                                            .listRowBackground(Color.white.opacity(0.06))
                                    }
                                } header: {
                                    Text(date)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .listStyle(.insetGrouped)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .task { await loadSessions() }
            .refreshable { await loadSessions() }
            .onChange(of: selectedPeriod) { _ in }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - Summary

    private var summaryRow: some View {
        let total = filteredSessions.reduce(0) { sum, s in
            if let mins = s.totalMinutes { return sum + mins }
            if let start = s.clockInDate {
                let end = s.clockOutDate ?? Date()
                return sum + Int(end.timeIntervalSince(start) / 60)
            }
            return sum
        }
        let h = total / 60
        let m = total % 60

        return HStack {
            VStack(alignment: .leading) {
                Text("Total Hours")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text("\(h)h \(m)m")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text("Sessions")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text("\(filteredSessions.count)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
        }
        .padding()
        .background(Color.white.opacity(0.06))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    // MARK: - Session Row

    private func sessionRow(_ session: AttendanceSession) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(session.locationName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)

                    if session.mode != .none {
                        Text(session.mode.displayName)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(session.mode == .secure ? Color.red.opacity(0.2) : Color(hex: "3B82F6").opacity(0.2))
                            .foregroundColor(session.mode == .secure ? .red : Color(hex: "3B82F6"))
                            .cornerRadius(4)
                    }
                }

                HStack(spacing: 4) {
                    if let inTime = session.clockInDate {
                        Text(DateFormatter.timeOnly.string(from: inTime))
                    }
                    if session.clockOutDate != nil {
                        Text("→")
                        if let outTime = session.clockOutDate {
                            Text(DateFormatter.timeOnly.string(from: outTime))
                        }
                    } else if session.isActive {
                        Text("→ now")
                            .foregroundColor(.green)
                    }
                }
                .font(.caption)
                .foregroundColor(.gray)

                if let addr = session.clockInAddress {
                    Text(addr)
                        .font(.caption2)
                        .foregroundColor(.gray.opacity(0.7))
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(session.durationText)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                HStack(spacing: 4) {
                    Image(systemName: session.isRemote == true ? "wifi" : "qrcode")
                        .font(.caption2)
                    Text(session.method?.capitalized ?? "")
                        .font(.caption2)
                }
                .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Grouping & Filtering

    private var filteredSessions: [AttendanceSession] {
        let calendar = Calendar.current
        let now = Date()
        return sessions.filter { session in
            guard let date = session.clockInDate else { return false }
            switch selectedPeriod {
            case .week:
                return calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear)
            case .month:
                return calendar.isDate(date, equalTo: now, toGranularity: .month)
            case .all:
                return true
            }
        }
    }

    private var groupedByDate: [(String, [AttendanceSession])] {
        let grouped = Dictionary(grouping: filteredSessions) { session -> String in
            guard let date = session.clockInDate else { return "Unknown" }
            return DateFormatter.dateOnly.string(from: date)
        }
        return grouped.sorted { a, b in
            let dateA = a.value.first?.clockInDate ?? .distantPast
            let dateB = b.value.first?.clockInDate ?? .distantPast
            return dateA > dateB
        }
    }

    private func loadSessions() async {
        isLoading = true
        sessions = await SupabaseService.shared.getSessionHistory(limit: 100)
        isLoading = false
    }
}
