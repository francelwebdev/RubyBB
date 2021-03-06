class MessagesController < ApplicationController
  before_filter :authenticate_user!, except: :show

  # GET /messages
  # GET /messages.json
  def index
    @meta = true
    begin
      p = params
      d = "domain:#{request.host}"

      # N+1 queries in the select. I still not find a clean way to check ACL here.
      @messages = Kaminari.paginate_array(Message.search(page: params[:page], load: { include: [:user, :topic, :updater, :small_messages => :user]}) do
        query { string "#{d} #{p[:q]}", default_operator: 'AND' }
        sort { by :at, 'desc' }
      end.select{|m| can? :read, m}).page(1)

    rescue
      flash[:error] = I18n.t('search.error')
      @messages = []
    end

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @messages }
    end
  end

  # GET /messages/1
  # GET /messages/1.json
  def show
    @message = Message.and_stuff.find(params[:id])
    authorize! :read, @message
    @unread = true

    respond_to do |format|
      format.html { render partial: 'show', format: :html, layout: false, locals: {message: @message} }
    end
  end

  # GET /messages/new
  # GET /messages/new.json
  def new
    @message = Message.new topic_id: params[:topic_id]
    authorize! :create, @message

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @message }
    end
  end

  # GET /messages/1/edit
  def edit
    @message = Message.find(params[:id])
    authorize! :update, @message
    @history = true
  end

  # POST /messages
  # POST /messages.json
  def create
    @message = Message.new(params[:message])
    @message.user_id = current_user.id
    authorize! :create, @message

    respond_to do |format|
      if @message.save
        PrivatePub.publish_to "/topics/#{@message.topic_id}", {id: @message.id}
        format.html { redirect_to topic_url(@message.topic, page: Topic.find(@message.topic_id).messages.page.num_pages, anchor: "m#{@message.id}"), notice: t('messages.created') }
        format.json { render json: @message, status: :created, location: @message }
      else
        format.html { render action: "new" }
        format.json { render json: @message.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /messages/1
  # PUT /messages/1.json
  def update
    @message = Message.find(params[:id])
    authorize! :update, @message
    @message.updater_id = current_user.id

    respond_to do |format|
      if @message.update_attributes(params[:message])
        format.html { redirect_to topic_url(@message.topic, page: params[:page]), notice: t('messages.updated') }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @message.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /messages/1
  # DELETE /messages/1.json
  def destroy
    @message = Message.find(params[:id])
    authorize! :destroy, @message
    if(@message == @message.topic.messages.first)
      r = forum_url(@message.forum)
      @message.topic.destroy
    else
      r = topic_url(@message.topic, page: params[:page])
      @message.destroy
    end

    respond_to do |format|
      format.html { redirect_to r }
      format.json { head :no_content }
    end
  end
end
