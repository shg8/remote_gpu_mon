import Foundation

struct NvidiaSMIParser {
    static let separator = "===SEP==="

    var command: String {
        """
        nvidia-smi --query-gpu=index,name,gpu_bus_id,utilization.gpu,memory.used,memory.total,temperature.gpu \
        --format=csv,noheader,nounits 2>&1; \
        echo '\(Self.separator)'; \
        nvidia-smi --query-compute-apps=gpu_bus_id,pid,process_name,used_gpu_memory \
        --format=csv,noheader,nounits 2>/dev/null; \
        echo '\(Self.separator)'; \
        ps -eo pid=,user= 2>/dev/null; true
        """
    }

    func parse(output: String) -> (gpus: [GPUMetrics], processes: [GPUProcess]) {
        let sections = output.components(separatedBy: Self.separator)

        let gpuSection = sections.count > 0
            ? sections[0].trimmingCharacters(in: .whitespacesAndNewlines) : ""
        let processSection = sections.count > 1
            ? sections[1].trimmingCharacters(in: .whitespacesAndNewlines) : ""
        let psSection = sections.count > 2
            ? sections[2].trimmingCharacters(in: .whitespacesAndNewlines) : ""

        let gpus = parseGPUs(gpuSection)
        let busIdToIndex = Dictionary(uniqueKeysWithValues: gpus.map { ($0.busId, $0.index) })
        let pidToUser = parsePsOutput(psSection)
        let processes = parseProcesses(processSection, busIdToIndex: busIdToIndex, pidToUser: pidToUser)

        return (gpus, processes)
    }

    // MARK: - Private

    private func parseGPUs(_ section: String) -> [GPUMetrics] {
        guard !section.isEmpty else { return [] }
        return section.split(separator: "\n").compactMap { line in
            let fields = line.split(separator: ",").map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            guard fields.count >= 7,
                  let index = Int(fields[0]),
                  let util = Int(fields[3]),
                  let memUsed = Int(fields[4]),
                  let memTotal = Int(fields[5]),
                  let temp = Int(fields[6])
            else { return nil }

            return GPUMetrics(
                index: index,
                name: fields[1],
                busId: fields[2],
                utilizationPercent: util,
                memoryUsedMB: memUsed,
                memoryTotalMB: memTotal,
                temperatureC: temp
            )
        }
    }

    private func parseProcesses(
        _ section: String,
        busIdToIndex: [String: Int],
        pidToUser: [Int: String]
    ) -> [GPUProcess] {
        guard !section.isEmpty, !section.contains("No running") else { return [] }
        return section.split(separator: "\n").compactMap { line in
            let fields = line.split(separator: ",").map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            guard fields.count >= 4,
                  let pid = Int(fields[1]),
                  let mem = Int(fields[3])
            else { return nil }

            return GPUProcess(
                pid: pid,
                processName: fields[2],
                gpuMemoryMB: mem,
                gpuIndex: busIdToIndex[fields[0]] ?? -1,
                user: pidToUser[pid] ?? "?"
            )
        }
    }

    private func parsePsOutput(_ section: String) -> [Int: String] {
        guard !section.isEmpty else { return [:] }
        var result: [Int: String] = [:]
        for line in section.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let parts = trimmed.split(separator: " ", maxSplits: 1)
            guard parts.count == 2, let pid = Int(parts[0]) else { continue }
            result[pid] = String(parts[1]).trimmingCharacters(in: .whitespaces)
        }
        return result
    }
}
