# frozen_string_literal: true

require "velum/salt"

# NodesController is responsible for everything related to nodes: showing
# information on nodes, deleting them, etc.
class NodesController < ApplicationController
  def index
    @minions = Minion.all

    respond_to do |format|
      format.html
      format.json { render json: @minions }
    end
  end

  def show
    @minion = Minion.find(params[:id])
  end

  # rubocop:disable Metrics/AbcSize
  # rubocop:disable Metrics/CyclomaticComplexity
  # rubocop:disable Metrics/PerceivedComplexity
  def assign
    minion = Minion.find(params[:node_id])
    minion_errors = []

    unless Minion.roles.keys.include?(params[:role])
      raise Minion::InvalidRole, "Could not assign role #{params[:role]}"
    end

    if minion.assign_role(params[:role].to_sym)
      # assign minion role to all minions if master was assigned correctly
      Minion.where(role: nil).each do |m|
        minion = m
        next if minion.assign_role(:minion)
        minion_errors.push(
          minion: minion,
          errors: minion.errors.full_messages.first || \
            "Failed to apply minion role to #{minion.hostname}"
        )
      end
    else
      minion_errors.push(
        minion: minion,
        errors: minion.errors.full_messages.first || \
          "Failed to apply master role to #{minion.hostname}"
      )
    end

    respond_to do |format|
      if minion_errors.any?
        error_message = minion_errors.map do |m|
          "#{m[:minion].hostname}: #{m[:errors]}"
        end.join(", ")
        format.html do
          flash[:error] = error_message
          redirect_to nodes_path
        end
        format.json { render json: error_message, status: :unprocessable_entity }
      else
        format.html { redirect_to nodes_path }
        format.json { head :ok }
      end
    end
  rescue Velum::SaltApi::SaltConnectionException,
         ActiveRecord::RecordNotFound,
         Minion::InvalidRole => e
    respond_to do |format|
      format.html do
        flash[:error] = e.message
        redirect_to nodes_path
      end
      format.json { render json: e.message, status: :unprocessable_entity }
    end
  end
  # rubocop:enable Metrics/AbcSize
  # rubocop:enable Metrics/CyclomaticComplexity
  # rubocop:enable Metrics/PerceivedComplexity

  # Bootstraps the cluster. This method will search for minions missing an
  # assigned role, assign a random role to it, and then call the salt
  # orchestration.
  def bootstrap
    if Minion.where(role: nil).count > 1
      Minion.assign_roles(roles: [:master], default_role: :minion)
      Velum::Salt.orchestrate
    else
      flash[:alert] = "Not enough Workers to bootstrap. Please start at least one worker."
    end

    redirect_to nodes_path
  end

  # TODO
  def destroy; end
end
