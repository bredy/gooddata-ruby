require 'gooddata'

describe "Full process and schedule exercise", :constraint => 'slow' do
  before(:all) do
    @client = ConnectionHelper::create_default_connection
    @project = @client.create_project(title: 'Project for schedule testing', auth_token: ConnectionHelper::GD_PROJECT_TOKEN)
    @process = @project.deploy_process('./spec/data/ruby_process',
                                  type: 'RUBY',
                                  name: 'Test ETL Process')
  end

  after(:all) do
    @process.delete if @process
    @project.delete if @project
    @client.disconnect
  end

  it "should be able to execute a process" do
    result = @process.execute(@process.executables.first)
    log = result.log
    expect(log.index('Hello Ruby executors')).not_to eq nil
    expect(log.index('Hello Ruby from the deep')).not_to eq nil
  end

  it "should be able to grab executables" do 

    expect(@process.executables).to eq ['process.rb']
  end

  it "should have empty schedules on deploy" do 
    expect(@process.schedules).to eq []
  end

  it "should be able to create schedule triggered by another schedule" do
    schedule_first = @process.create_schedule('0 15 27 7 *', @process.executables.first)
    schedule = @process.create_schedule(schedule_first, @process.executables.first)
    expect(@process.schedules.count).to eq 1
    expect(@process.schedules).to eq [schedule]
    schedule.delete
  end

  it "should be able to create schedule triggered by another schedule specified by ID" do
    schedule_first = @process.create_schedule('0 15 27 7 *', @process.executables.first)
    schedule = @process.create_schedule(schedule_first.obj_id, @process.executables.first)
    expect(@process.schedules.count).to eq 1
    expect(@process.schedules).to eq [schedule]
    schedule.delete
  end

  it "should be able to delete schedule" do
    schedule = @process.create_schedule('0 15 27 7 *', @process.executables.first)
    expect(@process.schedules.count).to eq 1
    expect(@process.schedules).to eq [schedule]
    schedule.delete
  end

  it "should be possible to read status of schedule" do
    schedule = @process.create_schedule('0 15 27 7 *', @process.executables.first)
    expect(schedule.state).to eq 'ENABLED'
    schedule.delete
  end

  it "should be possible to execute schedule" do
    schedule = @process.create_schedule('0 15 27 7 *', @process.executables.first)
    result = schedule.execute
    log = result.log
    expect(log.index('Hello Ruby executors')).not_to eq nil
    expect(log.index('Hello Ruby from the deep')).not_to eq nil
  end

  it "should be possible to deploy only a single file" do
    process = @project.deploy_process('./spec/data/hello_world_process/hello_world.rb',
                                  type: 'RUBY',
                                  name: 'Test ETL one file Process')
    begin
      schedule = process.create_schedule('0 15 27 7 *', process.executables.first)
      result = schedule.execute
      log = result.log
      expect(log.index('HELLO WORLD')).not_to eq nil
      expect(schedule.enabled?).to be_true
      schedule.disable
      schedule.save
      expect(schedule.enabled?).to be_false
      expect(schedule.disabled?).to be_true
      schedule.enable
      schedule.save
      expect(schedule.enabled?).to be_true
    ensure
      process && process.delete
    end
  end

  it "should be possible to deploy already zipped file" do
    process = @project.deploy_process('./spec/data/hello_world_process/hello_world.zip',
                                  type: 'RUBY',
                                  name: 'Test ETL zipped file Process')
    begin
      expect(process.schedules.count).to eq 0
      schedule = process.create_schedule('0 15 27 7 *', process.executables.first)
      result = schedule.execute
      log = result.log
      expect(log.index('HELLO WORLD')).not_to eq nil
      expect(process.schedules.count).to eq 1
    ensure
      process && process.delete
    end
  end

  it 'should be possible to deploy and run zipped file and print GoodData::VERSION' do
    process = @project.deploy_process('./spec/data/gooddata_version_process/gooddata_version.zip',
                                      type: 'RUBY',
                                      name: 'Test ETL zipped file GoodData Process')
    begin
      expect(process.schedules.count).to eq 0
      schedule = process.create_schedule('0 15 27 7 *', process.executables.first)
      result = schedule.execute
      log = result.log
      expect(log.index(GoodData::VERSION)).not_to eq nil
      expect(process.schedules.count).to eq 1
    ensure
      process && process.delete
    end
  end

  it 'should be possible to deploy and run zipped file and use nested parameters' do
    process = @project.deploy_process('./spec/data/ruby_params_process/ruby_params.zip',
                                      type: 'RUBY',
                                      name: 'Test ETL zipped file GoodData Process')
    begin
      expect(process.schedules.count).to eq 0
      params = {
        nested: {
          value: 42
        }
      }
      schedule = process.create_schedule('0 15 27 7 *', process.executables.first, params: params)
      result = schedule.execute
      log = result.log
      expect(log.index(JSON.parse(params.to_json).inspect)).not_to eq nil
      expect(process.schedules.count).to eq 1
    ensure
      process && process.delete
    end
  end

  it "should be possible to download deployed process" do
    size = File.size('./spec/data/hello_world_process/hello_world.zip')
    process = @project.deploy_process('./spec/data/hello_world_process/hello_world.zip',
                                  type: 'RUBY',
                                  name: 'Test ETL zipped file Process')
    begin
      Tempfile.open('downloaded-process') do |temp|
        temp << process.download
        temp.flush
        expect(File.size(temp.path)).to eq size
      end
    ensure
      process && process.delete
    end
  end
end
