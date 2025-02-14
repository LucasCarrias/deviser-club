class QuickTweetsController < ApplicationController
  before_action :set_quick_tweet, only: %i[ show edit update destroy ]
  before_action :authenticate_user!, only: %i[ edit update create destroy ]

  # GET /quick_tweets or /quick_tweets.json
  def index
    @quick_tweets = QuickTweet.published
    @quick_tweet = QuickTweet.new
  end

  # GET /quick_tweets/1 or /quick_tweets/1.json
  def show
    @quick_tweet.update(watches: @quick_tweet.watches + 1)
    @comments = @quick_tweet.comments.order(created_at: :desc)
  end

  # GET /quick_tweets/new
  def new
    @quick_tweet = QuickTweet.find_by(draft: true, user: current_user) || QuickTweet.new
  end

  # GET /quick_tweets/1/edit
  def edit
  end

  # POST /quick_tweets or /quick_tweets.json
  def create
    @quick_tweet = QuickTweet.find_by(draft: true, user: current_user) || QuickTweet.new(quick_tweet_params)
    @quick_tweet.body = quick_tweet_params[:body]
    @quick_tweet.draft = params[:commit].nil?
    @quick_tweet.ip_field = request.remote_ip
    @quick_tweet.user = current_user

    respond_to do |format|
      if @quick_tweet.draft
        @quick_tweet.skip_validations = true
        if @quick_tweet.save
          format.turbo_stream {
            render turbo_stream: turbo_stream.replace(
              "error_explanation", partial: 'components/errors',
              locals: { errors: @quick_tweet.errors })
          }
        end
        format.turbo_stream
      else
        if @quick_tweet.save
          @quick_tweet.generate_og_image
          format.html { redirect_to quick_tweet_url(@quick_tweet) }
          format.json { render :show, status: :created, location: @quick_tweet }
        else
          format.turbo_stream {
            render turbo_stream: turbo_stream.replace("error_explanation", partial: 'components/errors', locals: { errors: @quick_tweet.errors })
          }
          format.html { render :new, status: :unprocessable_entity }
          format.json { render json: @quick_tweet.errors, status: :unprocessable_entity }
        end
      end
    end
  end

  # PATCH/PUT /quick_tweets/1 or /quick_tweets/1.json
  def update
    @quick_tweet.draft = (@quick_tweet.draft and params[:commit].nil?)
    respond_to do |format|
      if @quick_tweet.draft
        @quick_tweet.skip_validations = true
        if @quick_tweet.update(quick_tweet_params.except(:tags))
          format.turbo_stream {
            render turbo_stream: turbo_stream.replace(
              "error_explanation", partial: 'components/errors',
              locals: { errors: @quick_tweet.errors })
          }
        end
      else
        if @quick_tweet.update(quick_tweet_params)
          @quick_tweet.broadcast_update partial: "quick_tweets/quick_tweet"
          # while updating, the target will be replaced/updated by the partial
          format.html { redirect_to quick_tweet_url(@quick_tweet) }
          format.json { render :show, status: :ok, location: @quick_tweet }
        else
          format.turbo_stream {
            render turbo_stream: turbo_stream.replace("error_explanation", partial: 'components/errors', locals: { errors: @quick_tweet.errors })
          }
          format.html { render :edit, status: :unprocessable_entity, alert: "Quick Tweet was not updated." }
          format.json { render json: @quick_tweet.errors, status: :unprocessable_entity }
        end
      end
    end
  end

  # DELETE /quick_tweets/1 or /quick_tweets/1.json
  def destroy
    @quick_tweet.destroy
    respond_to do |format|
      format.html { redirect_to root_path, alert: "Quick Tweet was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_quick_tweet
    @quick_tweet = QuickTweet.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def quick_tweet_params
    params.require(:quick_tweet).permit(:body, :commit)
  end
end
