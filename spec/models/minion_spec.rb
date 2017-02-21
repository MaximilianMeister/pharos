# frozen_string_literal: true
require "rails_helper"

describe Minion do
  it { is_expected.to validate_uniqueness_of(:hostname) }

  # rubocop:disable RSpec/ExampleLength
  describe ".assign_roles" do
    let(:minions) do
      FactoryGirl.create_list(:minion, 3, role: nil)
    end

    context "when a master role cannot be assigned" do
      before do
        minions
      end

      it "raises CouldNotAssignRole for master" do
        # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(described_class).to receive(:assign_role).with(:master)
          .and_return(false)
        # rubocop:enable RSpec/AnyInstance
        expect { described_class.assign_roles(roles: { master: [minions.first.hostname] }) }.to(
          raise_error(Minion::CouldNotAssignRole)
        )
      end

      it "raises CouldNotAssignRole for minion" do
        # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(described_class).to receive(:assign_role).with(:master)
          .and_return(true)
        allow_any_instance_of(described_class).to receive(:assign_role).with(:minion)
          .and_return(false)
        # rubocop:enable RSpec/AnyInstance
        expect { described_class.assign_roles(roles: { master: [minions.first.hostname] }) }.to(
          raise_error(Minion::CouldNotAssignRole)
        )
      end

      it "raises CouldNotAssignRole for a default_role" do
        # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(described_class).to receive(:assign_role).with(:master)
          .and_return(true)
        allow_any_instance_of(described_class).to receive(:assign_role).with(:minion)
          .and_return(true)
        allow_any_instance_of(described_class).to receive(:assign_role).with(:another_role)
          .and_return(false)
        allow(described_class).to receive(:where)
          .and_return(described_class.where(hostname: minions[2].hostname))
        # rubocop:enable RSpec/AnyInstance
        expect do
          described_class.assign_roles(
            # rubocop:disable Style/AlignHash
            roles: {
              master: [minions[0].hostname],
              minion: [minions[1].hostname]
            },
            default_role: :another_role
          )
          # rubocop:enable Style/AlignHash
        end.to raise_error(Minion::CouldNotAssignRole)
      end
    end

    context "when default_role is set" do
      before do
        minions
        # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(Velum::SaltMinion).to receive(:assign_role)
          .and_return(true)
        # rubocop:enable RSpec/AnyInstance
      end

      it "assigns the default role to the rest of the available minions" do
        # rubocop:disable Style/AlignHash
        described_class.assign_roles(
          roles: {
            master: [minions.first.hostname]
          },
          default_role: :minion
        )
        # rubocop:enable Style/AlignHash

        expect(described_class.all.map(&:role).sort).to eq(["master", "minion", "minion"])
      end
    end

    context "when default_role is not set" do
      before do
        minions
        # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(Velum::SaltMinion).to receive(:assign_role)
          .and_return(true)
        # rubocop:enable RSpec/AnyInstance
      end

      it "assigns the minion role to the rest of the available minions" do
        described_class.assign_roles(roles: { master: [minions.first.hostname] })

        expect(described_class.all.map(&:role)).to eq(["master", "minion", "minion"])
      end
    end

    context "when explicit minion role is set" do
      before do
        minions
        # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(Velum::SaltMinion).to receive(:assign_role)
          .and_return(true)
        # rubocop:enable RSpec/AnyInstance
      end

      it "assigns the minion role to specific minions" do
        described_class.assign_roles(
          roles: { master: [minions.first.hostname], minion: [minions.last.hostname] }
        )

        expect(described_class.all.last.role).to eq("minion")
      end
    end

    it "returns the ids of the minions that were assigned a role" do
      minions
      # rubocop:disable RSpec/AnyInstance
      allow_any_instance_of(Velum::SaltMinion).to receive(:assign_role)
        .and_return(true)
      # rubocop:enable RSpec/AnyInstance
      ids = described_class.assign_roles(
        roles: { master: [minions.first.hostname] }, default_role: :minion
      )

      expect(ids.sort).to eq(minions.map(&:id).sort)
    end
  end

  context "with some roles assigned" do
    let(:minion) { create(:minion, role: :master) }

    before { allow(minion.salt).to receive(:assign_role) { true } }

    it "returns false when calling assign_role" do
      expect(minion.assign_role(:other_role)).to be false
    end

    it "does not update the role in the database" do
      expect(minion.role).to eq("master")
    end
  end

  context "with no roles assigned" do
    let(:minion) { create(:minion, role: nil) }

    before { allow(minion.salt).to receive(:assign_role) { true } }

    it "returns true when calling assign_role" do
      expect(minion.reload.assign_role(:master)).to be true
    end

    it "updates the role in the database" do
      minion.assign_role(:master)
      expect(minion.reload.role).to eq("master")
    end

    it "updates the highstate column to 'pending' in the database" do
      minion.update!(highstate: :applied)
      expect { minion.assign_role(:master) }
        .to change { minion.reload.highstate }.from("applied")
        .to("pending")
    end

    context "role fails to be assigned on the remote" do
      before do
        allow(minion.salt).to receive(:assign_role) do
          raise Velum::SaltApi::SaltConnectionException
        end
      end

      it "does not save the role in the database" do
        expect(minion.assign_role(:master)).to be false
        expect(minion.reload.role).to be_nil
      end
    end
  end
  # rubocop:enable RSpec/ExampleLength
end
