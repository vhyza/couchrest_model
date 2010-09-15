# encoding: utf-8

require File.expand_path("../../spec_helper", __FILE__)
require File.join(FIXTURE_PATH, 'more', 'cat')
require File.join(FIXTURE_PATH, 'more', 'article')
require File.join(FIXTURE_PATH, 'more', 'course')
require File.join(FIXTURE_PATH, 'more', 'card')
require File.join(FIXTURE_PATH, 'base')

describe "Model Base" do
  
  before(:each) do
    @obj = WithDefaultValues.new
  end
  
  describe "instance database connection" do
    it "should use the default database" do
      @obj.database.name.should == 'couchrest-model-test'
    end
    
    it "should override the default db" do
      @obj.database = TEST_SERVER.database!('couchrest-extendedmodel-test')
      @obj.database.name.should == 'couchrest-extendedmodel-test'
      @obj.database.delete!
    end
  end
  
  describe "a new model" do
    it "should be a new document" do
      @obj = Basic.new
      @obj.rev.should be_nil
      @obj.should be_new
      @obj.should be_new_document
      @obj.should be_new_record
    end

    it "should not failed on a nil value in argument" do
      @obj = Basic.new(nil)
      @obj.should == { 'couchrest-type' => 'Basic' }
    end
  end
 
  describe "ActiveModel compatability Basic" do

    before(:each) do 
      @obj = Basic.new(nil)
    end

    describe "#to_key" do
      context "when the document is new" do
        it "returns nil" do
          @obj.to_key.should be_nil
        end
      end

      context "when the document is not new" do
        it "returns id in an array" do
          @obj.save
          @obj.to_key.should eql([@obj['_id']])
        end
      end
    end

    describe "#to_param" do
      context "when the document is new" do
        it "returns nil" do
          @obj.to_param.should be_nil
        end
      end

      context "when the document is not new" do
        it "returns id" do
          @obj.save
          @obj.to_param.should eql(@obj['_id'])
        end
      end
    end

    describe "#persisted?" do
      context "when the document is new" do
        it "returns false" do
          @obj.persisted?.should == false
        end
      end

      context "when the document is not new" do
        it "returns id" do
          @obj.save
          @obj.persisted?.should == true 
        end
      end
    end

    describe "#model_name" do
      it "returns the name of the model" do
        @obj.class.model_name.should eql('Basic')
        WithDefaultValues.model_name.human.should eql("With default values")
      end
    end


  end
  
  describe "update attributes without saving" do
    before(:each) do
      a = Article.get "big-bad-danger" rescue nil
      a.destroy if a
      @art = Article.new(:title => "big bad danger")
      @art.save
    end
    it "should work for attribute= methods" do
      @art['title'].should == "big bad danger"
      @art.update_attributes_without_saving('date' => Time.now, :title => "super danger")
      @art['title'].should == "super danger"
    end
    it "should silently ignore _id" do
      @art.update_attributes_without_saving('_id' => 'foobar')
      @art['_id'].should_not == 'foobar'
    end
    it "should silently ignore _rev" do
      @art.update_attributes_without_saving('_rev' => 'foobar')
      @art['_rev'].should_not == 'foobar'
    end
    it "should silently ignore created_at" do
      @art.update_attributes_without_saving('created_at' => 'foobar')
      @art['created_at'].should_not == 'foobar'
    end
    it "should silently ignore updated_at" do
      @art.update_attributes_without_saving('updated_at' => 'foobar')
      @art['updated_at'].should_not == 'foobar'
    end
    it "should also work using attributes= alias" do
      @art.respond_to?(:attributes=).should be_true
      @art.attributes = {'date' => Time.now, :title => "something else"}
      @art['title'].should == "something else"
    end
    
    it "should not flip out if an attribute= method is missing and ignore it" do
      lambda {
        @art.update_attributes_without_saving('slug' => "new-slug", :title => "super danger")
      }.should_not raise_error
      @art.slug.should == "big-bad-danger"
    end
    
    #it "should not change other attributes if there is an error" do
    #  lambda {
    #    @art.update_attributes_without_saving('slug' => "new-slug", :title => "super danger")        
    #  }.should raise_error
    #  @art['title'].should == "big bad danger"
    #end
  end
  
  describe "update attributes" do
    before(:each) do
      a = Article.get "big-bad-danger" rescue nil
      a.destroy if a
      @art = Article.new(:title => "big bad danger")
      @art.save
    end
    it "should save" do
      @art['title'].should == "big bad danger"
      @art.update_attributes('date' => Time.now, :title => "super danger")
      loaded = Article.get(@art.id)
      loaded['title'].should == "super danger"
    end
  end
  
  describe "with default" do
    it "should have the default value set at initalization" do
      @obj.preset.should == {:right => 10, :top_align => false}
    end

    it "should have the default false value explicitly assigned" do
      @obj.default_false.should == false
    end
    
    it "should automatically call a proc default at initialization" do
      @obj.set_by_proc.should be_an_instance_of(Time)
      @obj.set_by_proc.should == @obj.set_by_proc
      @obj.set_by_proc.should < Time.now
    end
    
    it "should let you overwrite the default values" do
      obj = WithDefaultValues.new(:preset => 'test')
      obj.preset = 'test'
    end
    
    it "should work with a default empty array" do
      obj = WithDefaultValues.new(:tags => ['spec'])
      obj.tags.should == ['spec']
    end
    
    it "should set default value of read-only property" do
      obj = WithDefaultValues.new
      obj.read_only_with_default.should == 'generic'
    end
  end

  describe "simplified way of setting property types" do
    it "should set defaults" do
      obj = WithSimplePropertyType.new
      obj.preset.should eql('none')
    end

    it "should handle arrays" do
      obj = WithSimplePropertyType.new(:tags => ['spec'])
      obj.tags.should == ['spec']
    end
  end
  
  describe "a doc with template values (CR::Model spec)" do
    before(:all) do
      WithTemplateAndUniqueID.all.map{|o| o.destroy}
      WithTemplateAndUniqueID.database.bulk_delete
      @tmpl = WithTemplateAndUniqueID.new
      @tmpl2 = WithTemplateAndUniqueID.new(:preset => 'not_value', 'important-field' => '1')
    end
    it "should have fields set when new" do
      @tmpl.preset.should == 'value'
    end
    it "shouldn't override explicitly set values" do
      @tmpl2.preset.should == 'not_value'
    end
    it "shouldn't override existing documents" do
      @tmpl2.save
      tmpl2_reloaded = WithTemplateAndUniqueID.get(@tmpl2.id)
      @tmpl2.preset.should == 'not_value'
      tmpl2_reloaded.preset.should == 'not_value'
    end
  end
  
  
  describe "finding all instances of a model" do
    before(:all) do
      WithTemplateAndUniqueID.req_design_doc_refresh
      WithTemplateAndUniqueID.all.map{|o| o.destroy}
      WithTemplateAndUniqueID.database.bulk_delete
      WithTemplateAndUniqueID.new('important-field' => '1').save
      WithTemplateAndUniqueID.new('important-field' => '2').save
      WithTemplateAndUniqueID.new('important-field' => '3').save
      WithTemplateAndUniqueID.new('important-field' => '4').save
    end
    it "should make the design doc" do
      WithTemplateAndUniqueID.all
      d = WithTemplateAndUniqueID.design_doc
      d['views']['all']['map'].should include('WithTemplateAndUniqueID')
    end
    it "should find all" do
      rs = WithTemplateAndUniqueID.all 
      rs.length.should == 4
    end
  end
  
  describe "counting all instances of a model" do
    before(:each) do
      @db = reset_test_db!
      WithTemplateAndUniqueID.req_design_doc_refresh
    end
    
    it ".count should return 0 if there are no docuemtns" do
      WithTemplateAndUniqueID.count.should == 0
    end
    
    it ".count should return the number of documents" do
      WithTemplateAndUniqueID.new('important-field' => '1').save
      WithTemplateAndUniqueID.new('important-field' => '2').save
      WithTemplateAndUniqueID.new('important-field' => '3').save
      
      WithTemplateAndUniqueID.count.should == 3
    end
  end
  
  describe "finding the first instance of a model" do
    before(:each) do      
      @db = reset_test_db!
      # WithTemplateAndUniqueID.req_design_doc_refresh # Removed by Sam Lown, design doc should be loaded automatically
      WithTemplateAndUniqueID.new('important-field' => '1').save
      WithTemplateAndUniqueID.new('important-field' => '2').save
      WithTemplateAndUniqueID.new('important-field' => '3').save
      WithTemplateAndUniqueID.new('important-field' => '4').save
    end
    it "should make the design doc" do
      WithTemplateAndUniqueID.all
      d = WithTemplateAndUniqueID.design_doc
      d['views']['all']['map'].should include('WithTemplateAndUniqueID')
    end
    it "should find first" do
      rs = WithTemplateAndUniqueID.first
      rs['important-field'].should == "1"
    end
    it "should return nil if no instances are found" do
      WithTemplateAndUniqueID.all.each {|obj| obj.destroy }
      WithTemplateAndUniqueID.first.should be_nil
    end
  end

  describe "lazily refreshing the design document" do
    before(:all) do
      @db = reset_test_db!
      WithTemplateAndUniqueID.new('important-field' => '1').save
    end
    it "should not save the design doc twice" do
      WithTemplateAndUniqueID.all
      WithTemplateAndUniqueID.req_design_doc_refresh
      WithTemplateAndUniqueID.refresh_design_doc
      rev = WithTemplateAndUniqueID.design_doc['_rev']
      WithTemplateAndUniqueID.req_design_doc_refresh
      WithTemplateAndUniqueID.refresh_design_doc
      WithTemplateAndUniqueID.design_doc['_rev'].should eql(rev)
    end
  end
  
  describe "getting a model with a subobject field" do
    before(:all) do
      course_doc = {
        "title" => "Metaphysics 410",
        "professor" => {
          "name" => ["Mark", "Hinchliff"]
        },
        "ends_at" => "2008/12/19 13:00:00 +0800"
      }
      r = Course.database.save_doc course_doc
      @course = Course.get r['id']
    end
    it "should load the course" do
      @course["professor"]["name"][1].should == "Hinchliff"
    end
    it "should instantiate the professor as a person" do
      @course['professor'].last_name.should == "Hinchliff"
    end
    it "should instantiate the ends_at as a Time" do
      @course['ends_at'].should == Time.parse("2008/12/19 13:00:00 +0800")
    end
  end
  
  describe "timestamping" do
    before(:each) do
      oldart = Article.get "saving-this" rescue nil
      oldart.destroy if oldart
      @art = Article.new(:title => "Saving this")
      @art.save
    end
    
    it "should define the updated_at and created_at getters and set the values" do
      @obj.save
      obj = WithDefaultValues.get(@obj.id)
      obj.should be_an_instance_of(WithDefaultValues)
      obj.created_at.should be_an_instance_of(Time)
      obj.updated_at.should be_an_instance_of(Time)
      obj.created_at.to_s.should == @obj.updated_at.to_s
    end
    
    it "should not change created_at on update" do
      2.times do 
        lambda do
          @art.save
        end.should_not change(@art, :created_at)
      end
    end
     
    it "should set the time on create" do
      (Time.now - @art.created_at).should < 2
      foundart = Article.get @art.id
      foundart.created_at.should == foundart.updated_at
    end
    it "should set the time on update" do
      @art.save
      @art.created_at.should < @art.updated_at
    end
  end
  
  describe "getter and setter methods" do
    it "should try to call the arg= method before setting :arg in the hash" do
      @doc = WithGetterAndSetterMethods.new(:arg => "foo")
      @doc['arg'].should be_nil
      @doc[:arg].should be_nil
      @doc.other_arg.should == "foo-foo"
    end
  end

  describe "initialization" do
    it "should call after_initialize method if available" do
      @doc = WithAfterInitializeMethod.new
      @doc['some_value'].should eql('value')
    end
  end
  
  describe "recursive validation on a model" do
    before :each do
      reset_test_db!
      @cat = Cat.new(:name => 'Sockington')
    end
    
    it "should not save if a nested casted model is invalid" do
      @cat.favorite_toy = CatToy.new
      @cat.should_not be_valid
      @cat.save.should be_false
      lambda{@cat.save!}.should raise_error
    end
    
    it "should save when nested casted model is valid" do
      @cat.favorite_toy = CatToy.new(:name => 'Squeaky')
      @cat.should be_valid
      @cat.save.should be_true
      lambda{@cat.save!}.should_not raise_error
    end
    
    it "should not save when nested collection contains an invalid casted model" do
      @cat.toys = [CatToy.new(:name => 'Feather'), CatToy.new]
      @cat.should_not be_valid
      @cat.save.should be_false
      lambda{@cat.save!}.should raise_error
    end
    
    it "should save when nested collection contains valid casted models" do
      @cat.toys = [CatToy.new(:name => 'feather'), CatToy.new(:name => 'ball-o-twine')]
      @cat.should be_valid
      @cat.save.should be_true
      lambda{@cat.save!}.should_not raise_error
    end
    
    it "should not fail if the nested casted model doesn't have validation" do
      Cat.property :trainer, Person
      Cat.validates_presence_of :name
      cat = Cat.new(:name => 'Mr Bigglesworth')
      cat.trainer = Person.new
      cat.should be_valid
      cat.save.should be_true
    end
  end

  describe "searching the contents of a model" do
    before :each do
      @db = reset_test_db!

      names = ["Fuzzy", "Whiskers", "Mr Bigglesworth", "Sockington", "Smitty", "Sammy", "Samson", "Simon"]
      names.each { |name| Cat.create(:name => name) }

      search_function = { 'defaults' => {'store' => 'no', 'index' => 'analyzed_no_norms'},
          'index' => "function(doc) { ret = new Document(); ret.add(doc['name'], {'field':'name'}); return ret; }" }
      @db.save_doc({'_id' => '_design/search', 'fulltext' => {'cats' => search_function}})
    end

    it "should be able to paginate through a large set of search results" do
      if couchdb_lucene_available?
        names = []
        Cat.paginated_each(:design_doc => "_design/search", :view_name => "cats",
             :q => 'name:S*', :search => true, :include_docs => true, :per_page => 3) do |cat|
           cat.should_not be_nil
           names << cat.name
        end

        names.size.should == 5
        names.should include('Sockington')
        names.should include('Smitty')
        names.should include('Sammy')
        names.should include('Samson')
        names.should include('Simon')
      end
    end
  end

end
