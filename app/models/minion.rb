# frozen_string_literal: true

require "velum/salt_minion"

# Minion represents the minions that have been registered in this application.
class Minion < ApplicationRecord
  # Raised when trying to bootstrap more minions than those available
  # (E.g. assign roles [:master, :minion] when there is only one minion)
  class NotEnoughMinions < StandardError; end
  # Raised when we fail to assign a role on a minion
  class CouldNotAssignRole < StandardError; end
  # Raised when Minion doesn't exist
  class NonExistingMinion < StandardError; end

  enum highstate: [:not_applied, :pending, :failed, :applied]
  enum role: [:master, :minion]

  validates :hostname, presence: true, uniqueness: true

  # Example:
  #   Minion.assign_roles(
  #     roles: {
  #       master: ["master.example.com"],
  #       minion: ["minion1.example.com"]
  #     },
  #     default_role: :dns
  #   )
  # rubocop:disable Metrics/AbcSize
  # rubocop:disable Metrics/CyclomaticComplexity
  # rubocop:disable Metrics/PerceivedComplexity
  def self.assign_roles(roles: {}, default_role: :minion)
    if roles[:master].any? && !Minion.exists?(hostname: roles[:master])
      raise NonExistingMinion, "Failed to process non existing minion: #{roles[:master].first}"
    end
    master = Minion.find_by(hostname: roles[:master].first)
    # choose requested minions or all other than master
    minions = Minion.where(role: roles[:minion]).where.not(hostname: roles[:master].first)

    # assign master if requested
    assigned_ids = []
    if master
      # rubocop:disable Style/GuardClause
      if master.assign_role(:master)
        assigned_ids << master.id
      else
        raise CouldNotAssignRole, "Failed to assign master role to #{master.hostname}"
      end
      # rubocop:enable Style/GuardClause
    end

    minions.find_each do |minion|
      unless minion.assign_role(:minion)
        raise CouldNotAssignRole, "Failed to assign minion role to #{minion.hostname}"
      end
      assigned_ids << minion.id
    end

    # assign default role if there is any minion left with no role
    if default_role
      Minion.where(role: nil).find_each do |minion|
        unless minion.assign_role(default_role)
          raise CouldNotAssignRole, "Failed to assign #{default_role} role to #{minion.hostname}"
        end
        assigned_ids << minion.id
      end
    end

    assigned_ids
  end
  # rubocop:enable Metrics/AbcSize
  # rubocop:enable Metrics/CyclomaticComplexity
  # rubocop:enable Metrics/PerceivedComplexity

  # rubocop:disable SkipsModelValidations
  # Assigns a role to this minion locally in the database, and send that role
  # to salt subsystem.
  def assign_role(new_role)
    return false if role.present?

    Minion.transaction do
      # We set highstate to pending since we just assigned a new role
      update_columns(role:      Minion.roles[new_role],
                     highstate: Minion.highstates[:pending])
      salt.assign_role new_role
    end
    true
  rescue Velum::SaltApi::SaltConnectionException
    errors.add(:base, "Failed to apply role #{new_role} to #{hostname}")
    false
  end
  # rubocop:enable SkipsModelValidations

  # Returns the proxy for the salt minion
  def salt
    @salt ||= Velum::SaltMinion.new minion_id: hostname
  end
end
