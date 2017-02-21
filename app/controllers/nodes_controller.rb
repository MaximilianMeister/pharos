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

  def assign_roles
    Minion.assign_roles(roles: { master: [params[:hostname]] })

    respond_to do |format|
      format.html { redirect_to nodes_path }
      format.json { head :ok }
    end
  rescue Minion::CouldNotAssignRole,
         Minion::NonExistingMinion => e
    respond_to do |format|
      format.html do
        flash[:error] = e.message
        redirect_to nodes_path
      end
      format.json { render json: e.message, status: :unprocessable_entity }
    end
  end

  # Bootstraps the cluster. This method will search for minions missing an
  # assigned role, assign a random role to it, and then call the salt
  # orchestration.
  def bootstrap
    if Minion.where(role: nil).count > 1
      # choose first minion to be the master
      Minion.assign_roles(roles: { master: [Minion.first.hostname] })
      Velum::Salt.orchestrate
    else
      flash[:alert] = "Not enough Workers to bootstrap. Please start at least one worker."
    end

    redirect_to nodes_path
  end

  # TODO
  def destroy; end
end
