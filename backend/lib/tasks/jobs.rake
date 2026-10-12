# lib/tasks/jobs.rake
namespace :jobs do
  desc "Show recent Solid Queue jobs and their status (LIMIT=20)"
  task status: :environment do
    limit = (ENV["LIMIT"] || 20).to_i

    in_state = {
      "failed"    => SolidQueue::FailedExecution,
      "running"   => SolidQueue::ClaimedExecution,
      "ready"     => SolidQueue::ReadyExecution,
      "scheduled" => SolidQueue::ScheduledExecution,
      "blocked"   => SolidQueue::BlockedExecution
    }.transform_values { |model| model.pluck(:job_id).to_set }

    errors = SolidQueue::FailedExecution.pluck(:job_id, :error).to_h

    jobs = SolidQueue::Job.order(id: :desc).limit(limit)
    jobs.each do |job|
      status = job.finished_at ? "finished" : in_state.find { |_, ids| ids.include?(job.id) }&.first || "unknown"

      args   = job.arguments.is_a?(Hash) ? job.arguments["arguments"] : job.arguments
      target = Array(args).filter_map { |a| a["_aj_globalid"]&.split("/")&.last(2)&.join("#") if a.is_a?(Hash) }.join(", ")

      line = format("%-6d %-24s %-14s %-10s %s", job.id, job.class_name, target, status, job.created_at.strftime("%H:%M:%S"))
      if status == "failed"
        err  = errors[job.id]
        err  = JSON.parse(err) if err.is_a?(String)
        line += "  → #{err['exception_class']}: #{err['message']}"
      end
      puts line
    end

    counts = in_state.transform_values(&:size).merge("finished" => SolidQueue::Job.where.not(finished_at: nil).count)
    puts "\n" + counts.map { |k, v| "#{k}: #{v}" }.join("  ")
    puts "workers alive: #{SolidQueue::Process.count}"
  end
end
