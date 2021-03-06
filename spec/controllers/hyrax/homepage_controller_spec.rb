RSpec.describe Hyrax::HomepageController, type: :controller do
  routes { Hyrax::Engine.routes }

  describe "#index" do
    let(:user) { create(:user) }

    before do
      sign_in user
      2.times { create(:work, user: user) }
    end

    context 'with existing featured researcher' do
      let!(:bilbo) { ContentBlock.create!(name: ContentBlock::RESEARCHER, value: 'Biblo Baggins', created_at: 2.hours.ago) }
      let!(:frodo) { ContentBlock.create!(name: ContentBlock::RESEARCHER, value: 'Frodo Baggins', created_at: Time.zone.now) }

      it 'finds the featured researcher' do
        get :index
        expect(response).to be_success
        expect(assigns(:featured_researcher)).to eq frodo
      end
    end

    context 'with no featured researcher' do
      it "sets featured researcher" do
        get :index
        expect(response).to be_success
        assigns(:featured_researcher).tap do |researcher|
          expect(researcher).to be_kind_of ContentBlock
          expect(researcher.name).to eq 'featured_researcher'
        end
      end
    end

    it "sets marketing text" do
      get :index
      expect(response).to be_success
      assigns(:marketing_text).tap do |marketing|
        expect(marketing).to be_kind_of ContentBlock
        expect(marketing.name).to eq 'marketing_text'
      end
    end

    it "does not include other user's private documents in recent documents" do
      get :index
      expect(response).to be_success
      titles = assigns(:recent_documents).map { |d| d['title_tesim'][0] }
      expect(titles).not_to include('Test Private Document')
    end

    it "includes only GenericWork objects in recent documents" do
      get :index
      assigns(:recent_documents).each do |doc|
        expect(doc[Solrizer.solr_name("has_model", :symbol)]).to eql ["GenericWork"]
      end
    end

    context "with a document not created this second" do
      before do
        gw3 = GenericWork.new(title: ['Test 3 Document'], read_groups: ['public'])
        gw3.apply_depositor_metadata('mjg36')
        # stubbing to_solr so we know we have something that didn't create in the current second
        old_to_solr = gw3.method(:to_solr)
        allow(gw3).to receive(:to_solr) do
          old_to_solr.call.merge(
            Solrizer.solr_name('system_create', :stored_sortable, type: :date) => 1.day.ago.iso8601
          )
        end
        gw3.save
      end

      it "sets recent documents in the right order" do
        get :index
        expect(response).to be_success
        expect(assigns(:recent_documents).length).to be <= 4
        create_times = assigns(:recent_documents).map { |d| d['system_create_dtsi'] }
        expect(create_times).to eq create_times.sort.reverse
      end
    end

    context "with admin sets enabled", :clean_repo do
      let(:admin_set_doc) do
        {
          "system_create_dtsi" => "2016-09-12T19:36:51Z",
          "has_model_ssim" => ["AdminSet"],
          "id" => "w3763695z",
          "title_tesim" => ["A completely unique name"],
          "description_tesim" => ["A substantial description"],
          "thumbnail_path_ss" => "/assets/admin-set-thumb.png",
          "read_access_group_ssim" => ["public"]
        }
      end

      it "sets the admin_sets" do
        ActiveFedora::SolrService.add(admin_set_doc, commit: true)
        get :index
        expect(response).to be_success
        expect(assigns(:admin_sets).map(&:id)).to eq [admin_set_doc["id"]]
      end
    end

    it "sets the presenter" do
      get :index
      expect(response).to be_success
      expect(assigns(:presenter)).to be_kind_of Hyrax::HomepagePresenter
    end

    context "with featured works" do
      let!(:my_work) { FactoryGirl.create(:work, user: user) }

      before do
        FeaturedWork.create!(work_id: my_work.id)
      end

      it "sets featured works" do
        get :index
        expect(response).to be_success
        expect(assigns(:featured_work_list)).to be_kind_of FeaturedWorkList
      end
    end

    it "sets announcement content block" do
      get :index
      expect(response).to be_success
      assigns(:announcement_text).tap do |announcement|
        expect(announcement).to be_kind_of ContentBlock
        expect(announcement.name).to eq 'announcement_text'
      end
    end

    context "without solr" do
      before do
        allow(controller).to receive(:repository).and_return(instance_double(Blacklight::Solr::Repository))
        allow(controller.repository).to receive(:search).and_raise Blacklight::Exceptions::InvalidRequest
      end

      it "errors gracefully" do
        get :index
        expect(response).to be_success
        expect(assigns(:admin_sets)).to be_blank
        expect(assigns(:recent_documents)).to be_blank
      end
    end
  end
end
