require 'spec_helper'

RSpec.describe Hyrax::Workflow::GrantReadToDepositor do
  let(:depositor) { create(:user) }
  let(:user) { User.new }

  describe ".call" do
    subject do
      described_class.call(target: work,
                           comment: "A pleasant read",
                           user: user)
    end

    context "with no additional viewers" do
      let(:work) { create(:work_without_access, depositor: depositor.user_key) }

      it "adds read access" do
        expect { subject }.to change { work.read_users }.from([]).to([depositor.user_key])
        expect(work).to be_valid
      end
    end

    context "with an additional viewers" do
      let(:viewer) { create(:user) }
      let(:work) { create(:work_without_access, depositor: depositor.user_key, read_users: [viewer.user_key]) }

      it "adds read access" do
        expect { subject }.to change { work.read_users }.from([viewer.user_key]).to([viewer.user_key, depositor.user_key])
        expect(work).to be_valid
      end
    end
  end
end
