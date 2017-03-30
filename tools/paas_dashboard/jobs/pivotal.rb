require 'pivotal-tracker' # https://github.com/jsmestad/pivotal-tracker

PivotalTracker::Client.token = ENV['PIVOTAL_API_KEY'] || 'abc'
@project = PivotalTracker::Project.find(ENV['PIVOTAL_PROJECT_ID'])

SCHEDULER.every '10m', :first_in => 0 do
  if @project.is_a?(PivotalTracker::Project)
    @iteration = PivotalTracker::Iteration.current(@project)

    critical = 0
    warnings = 0
    unknowns = 0

    support_stories = @iteration.stories.all(:label => ['support', "'small' task"])
    stories = support_stories.length

    if stories > 5
      critical = stories
    elsif stories <= 5
      warnings = stories
    end

    send_event(
        'pivotal_counts',
        criticals: critical,
        warnings: warnings,
        unknowns: unknowns
    )
  else
    puts 'Not a Pivotal project'
  end
end