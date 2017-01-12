
def SCHEDULER.handle_exception(job, exception)
  puts "Job #{job.id} caught exception '#{exception}'"
end