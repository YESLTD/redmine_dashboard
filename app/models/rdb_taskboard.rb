class RdbTaskboard < RdbDashboard

  def init
    # Init filters
    self.add_filter RdbDashboard::AssigneeFilter.new
    self.add_filter RdbDashboard::VersionFilter.new
    self.add_filter RdbDashboard::TrackerFilter.new
    self.add_filter RdbDashboard::CategoryFilter.new
  end

  def setup(params)
    super

    if ['tracker', 'priority', 'assignee', 'category', 'version', 'none'].include? params[:group]
      options[:group] = params[:group].to_sym
    end

    if params[:hide_done]
      options[:hide_done] = (params[:hide_done] == 'true')
    end

    if params[:change_assignee]
      options[:change_assignee] = (params[:change_assignee] == 'true')
    end

    if id = params[:column]
      options[:hide_columns] ||= []
      options[:hide_columns].include?(id) ? options[:hide_columns].delete(id) : (options[:hide_columns] << id)
    end
  end

  def build
    # Init columns
    options[:hide_columns] ||= []
    done_statuses = IssueStatus.sorted.select do |status|
      next true if status.is_closed?
      self.add_column RdbTaskboard::Column.new("s#{status.id}", status.name, status,
        :hide => options[:hide_columns].include?("s#{status.id}"))
      false
    end
    self.add_column RdbTaskboard::Column.new("sX", :rdb_column_done, done_statuses,
      :compact => options[:hide_done], :hide => options[:hide_columns].include?("sX"))

    # Init groups
    case options[:group]
    when :tracker
      project.trackers.each do |tracker|
        self.add_group RdbDashboard::Group.new("tracker-#{tracker.id}", tracker.name, :accept => Proc.new {|issue| issue.tracker == tracker })
      end
    when :priority
      IssuePriority.find(:all).reverse.each do |p|
        self.add_group RdbDashboard::Group.new("priority-#{p.position}", p.name, :accept => Proc.new {|issue| issue.priority_id == p.id })
      end
    when :assignee
      self.add_group RdbDashboard::Group.new(:assigne_me, :rdb_filter_assignee_me, :accept => Proc.new {|issue| issue.assigned_to_id == User.current.id })
      self.add_group RdbDashboard::Group.new(:assigne_none, :rdb_filter_assignee_none, :accept => Proc.new {|issue| issue.assigned_to_id.nil? })
      self.add_group RdbDashboard::Group.new(:assigne_other, :rdb_filter_assignee_others, :accept => Proc.new {|issue| !issue.assigned_to_id.nil? and issue.assigned_to_id != User.current.id })
    when :category
      project.issue_categories.each do |category|
        self.add_group RdbDashboard::Group.new("category-#{category.id}", category.name, :accept => Proc.new {|issue| issue.category_id == category.id })
      end
      self.add_group RdbDashboard::Group.new(:category_none, :rdb_unassigned, :accept => Proc.new {|issue| issue.category.nil? })
    when :version
      project.versions.each do |version|
        self.add_group RdbDashboard::Group.new("version-#{version.id}", version.name, :accept => Proc.new {|issue| issue.fixed_version_id == version.id })
      end
      self.add_group RdbDashboard::Group.new(:version_none, :rdb_unassigned, :accept => Proc.new {|issue| issue.fixed_version.nil? })
    end

    self.add_group RdbDashboard::Group.new(:all, :rdb_all_issues) if groups.empty?
  end


  # -------------------------------------------------------
  # Helpers

  def issues_for(column)
    filter column.scope(project.issues)
  end

  def columns; @columns ||= HashWithIndifferentAccess.new end
  def add_column(column)
    column.board = self
    columns[column.id.to_s] = column
  end
end