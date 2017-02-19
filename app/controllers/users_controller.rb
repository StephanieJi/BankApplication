class UsersController < ApplicationController
  include UsersHelper

  def new
    logger.info("(#{self.class.to_s}) (#{action_name}) -- Entering the SignUp page")
  	@user = User.new
  end
 
  def show
    logger.info("(#{self.class.to_s}) (#{action_name}) -- Fetch User from db")
  	@user = User.find(params[:id])
  end
  
  def create
    logger.info("(#{self.class.to_s}) (#{action_name}) -- Model action to create a new user in db")
    #Check if the user already exists in the DB if so redirect to error with message user already exists
    puts params[:email]
    @user = User.find_by_email(params[:email])
    if !@user.nil?
      #User already exists
      flash[:success] = "User already exists!"
      redirect_to login_url
    end
  	
    @user = User.new(user_params)
  	if @user.save
      log_in @user
  		flash[:success] = "Welcome to the Sample App!"
  		redirect_to login_url
  	else
  		render 'new'
  	end	
  end

  private
 	def user_params
  	params.require(:user).permit(:name, :email,:password,:password_confirmation)
  end
end
