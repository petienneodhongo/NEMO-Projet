# frozen_string_literal: true

module ApplicationController::Crud
  extend ActiveSupport::Concern

  # attempts to destroy obj and add an i18n'd success message to flash
  # on error, translates the error message and adds that to flash
  def destroy_and_handle_errors(obj, options = {})
    obj.send(options[:but_first]) if options[:but_first]
    obj.destroy
    flash[:success] = "#{obj.class.model_name.human} #{t('errors.messages.deleted_successfully')}"
  rescue DeletionError # Deprecated
    flash[:error] =
      t($ERROR_INFO.to_s, scope: [:activerecord, :errors, :models, obj.class.model_name.i18n_key],
                          default: t("errors.messages.generic_delete_error"))
  rescue ActiveRecord::DeleteRestrictionError => e # Preferred method
    assn_name = e.to_s.split(" ")[-1]
    model = obj.class.model_name.i18n_key
    key = "activerecord.errors.models.#{model}.cant_delete_if_has_#{assn_name}"
    flash[:error] = t(key, default: t("errors.messages.generic_delete_error"))
  end

  # Handles ParamaterMissing errors
  def handle_parameter_missing
    render(body: nil, status: :bad_request)
  end

  # returns a success message based on the given object
  def success_msg(obj)
    # get verb (past tense) based on action.
    # treat sub-actions such as `enketo_update` like the regular `update` action.
    verb = t("common.#{params[:action].split('_').last}d").downcase
    "#{obj.class.model_name.human.ucwords} #{verb} #{t('common.successfully').downcase}."
  end

  # sets a success message based on the given object
  def set_success(obj)
    flash[:success] = success_msg(obj)
  end

  # sets a success message and redirects
  def set_success_and_redirect(obj, options = {})
    # redirect to index_url_with_context by default
    options[:to] ||= index_url_with_context

    # save the object id in the flash in case the view wants to have some fun with it
    flash[:modified_obj_id] = obj.id

    # if options[:to] is a symbol, we really mean action: xxx
    options[:to] = {action: options[:to]} if options[:to].is_a?(Symbol)

    set_success(obj)

    # do the redirect
    redirect_to(options[:to])
  end

  # gets the url to an index action, ensuring the appropriate page is returned to
  # target_controller - the controller whose index should be used. defaults to current controller
  def index_url_with_context(target_controller = nil, **extra_params)
    target_controller ||= controller_name
    url_params = {controller: target_controller, action: :index}.merge(get_last_context).merge(extra_params)
    url_for(url_params)
  end

  # remembers the last visited page number for each controller and mission
  def remember_context
    remember_search(params[:search]) if params[:search]
    remember_page(params[:page]) if params[:page]
  end

  def remember_search(search)
    session[:last_searches] ||= {}
    session[:last_searches][last_context_hash_key] = search
  end

  def remember_page(page)
    session[:last_page_numbers] ||= {}
    session[:last_page_numbers][last_context_hash_key] = page
  end

  # builds a simple hash key for remembering page context
  def last_context_hash_key
    controller_name + current_mission.try(:id).to_s
  end

  def get_last_context
    page = get_last_page_number if session[:last_page_numbers]
    search = get_last_searches if session[:last_searches]
    {page: page, search: search}
  end

  def get_last_page_number
    return unless session[:last_page_numbers]
    session[:last_page_numbers][last_context_hash_key].presence
  end

  def get_last_searches
    return unless session[:last_searches]
    session[:last_searches][last_context_hash_key].presence
  end

  # gets the request's referrer without the query string
  def referrer_without_query_string
    ref = URI(request.referer)
    ref.to_s.gsub("?#{ref.query}", "")
  end
end
