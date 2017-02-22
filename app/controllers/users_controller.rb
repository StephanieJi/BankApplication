class UsersController < ApplicationController
    include UsersHelper

    def index
      if params[:search]
        @users = User.search(params[:search]).order("created_at ASC")
      end
    end

    def new
      logger.info("(#{self.class.to_s}) (#{action_name}) -- Entering the SignUp page")
      @user = User.new
    end
 
    def show
      logger.info("(#{self.class.to_s}) (#{action_name}) -- Fetch User from db")
      @user = User.find(params[:id])	
      if is_same_user?(@user,current_user)
        @user
      else
        flash[:error] = "Invalid Operation"
        redirect_to root_url
      end
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
  		  flash[:success] = "Welcome to the Bank App!"
  		  redirect_to login_url
  	  else
  		  render 'new'
  	  end	
    end

    def edit
  	  @user = User.find(params[:id])
      if is_same_user?(@user,current_user)
        @user
      else
        flash[:error] = "Invalid Operation"
        redirect_to root_url
      end
    end

    def update
  	  @user = User.find(params[:id])
  	  if @user.update_attributes(user_params)
  		  flash[:success] = "Profile updated"
    	  redirect_to @user
  	  else
  		  render 'edit'
  	  end
    end

    def account
  	  @user = current_user
      @accounts = Account.where(:user_id => current_user) 

  	  respond_to do |format|
        format.html 
        format.json { render json: @accounts }
      end
    end

    def account_create_request
      @user = User.find(params[:id])
   
      account = Account.create(:user_id => @user.id,:balance => 0, :status => 3)
      if account.save
        flash[:success] = "Your request for a new account is awaiting administrator approval."
      else
        flash[:error] = "Request for a new account failed!"
      end
    end

    def search_for_users
      if params[:search]
        @users = User.search(params[:search]).order("created_at DESC")
      end
    end

    def add_friend   
      f = Friend.new
      f.user_id = current_user.id
      f.friend_id = params[:id]

      if are_they_friends(current_user,f)
        flash[:danger] = "You are already friends"
      else
        if f.save
          flash[:success] = "You are now friends" 
        else
          flash[:error] = "Failed to save in the database"
          puts f.errors.messages.inspect
        end
      end
      redirect_to search_for_users_url
    end

    def show_friends
      @user = User.find(params[:id])
      if is_same_user?(@user,current_user)  
        @friends = Friend.where(:user_id => params[:id])
        @your_friends = []

        @friends.each do |t|
          @your_friends.push( User.find(t.friend_id))
        end

        @friends = Friend.where(:friend_id => params[:id])
        @friends.each do |t|
          @your_friends.push( User.find(t.user_id))
        end

        respond_to do |format|
          format.html 
          format.json { render json: @friends }
        end
      else
        flash[:error] = "Invalid Operation"
        redirect_to root_url
      end
    end

    def show_transactions
      @user = User.find(params[:id])
      @accounts = Account.where(:user_id => @user.id)
      #@transactions = []
      #@transfers = []
      #puts "This is a test #{@accounts.kind_of?(Array)} #{@accounts[0].id}"
      #if !@accounts.nil?    
      #  @accounts.each do |account|
      #    #@transactions = account.transactions
      #    @transactions += Transaction.where(:account_id => account.id)
      #    puts @transactions[0].transfer.account_id
          #@transfers += Transfer.where(:account_id => account.id)  
      #  end
      #end
    end

    def transfer_money
      @friend = User.find(params[:id])
      @source_accounts = Account.where(:user_id => current_user)
      @destination_accounts = Account.where(:user_id => @friend.id)
      if request.post?
      #current_user_account = Account.find_by(account_id: params["account_id"].to_i)
      #puts BigNum(params["account_id"].to_i).class
      #puts current_user_account.nil?
      #account_balance = (current_user_account).balance
      #amount = params["amount"]
      #if(account_balance>amount)x`x
      #  puts "can transfer"
      #else
      #  puts "can't transfer"
      #end
      end
    end

    def deposit
      @accounts = Account.where(:user_id => current_user, :status => 1)
      if request.post?
        @account = Account.find(params[:account_id].to_i)
        @account.balance += params[:amount].to_f

        if @account.save
          @Transaction = Transaction.new
          @Transaction.transaction_type = deposit_type
          @Transaction.status = approved_status
          @Transaction.start = Time.now
          @Transaction.finish = Time.now
          @Transaction.amount = params[:amount].to_f
          @Transaction.account_id = params[:account_id].to_i

          if @Transaction.save
            flash[:success] = "Deposit was Successful"
            redirect_to account_url
          else
            flash[:danger] = "Deposit was Successful, but failed to record transaction"
            redirect_to account_url
          end
        else
          flash[:error] = "Deposit was Unsuccessful"
          redirect_to root_url
        end
      end
    end

    def withdraw
      @accounts = Account.where(:user_id => current_user, :status => 1)
      if request.post?
        @account = Account.find(params[:account_id].to_i)
        withdraw_amount = params[:amount].to_f

        if is_valid_withdraw(@account, withdraw_amount)
          if withdraw_amount >= 1000.0
            @Transaction = Transaction.new
            @Transaction.transaction_type = withdraw_type
            @Transaction.status = pending_status
            @Transaction.start = Time.now
            @Transaction.finish = Time.now
            @Transaction.amount = withdraw_amount
            @Transaction.account_id = params[:account_id].to_i

            if @Transaction.save
              flash[:success] = "Transaction initiated. Admin approval needed"
            else
              flash[:error] = "Transaction failed. Retry again"
              redirect_to withdraw_url
            end
          elsif withdraw_amount > 0 && withdraw_amount < 1000.0
            @account.balance -= withdraw_amount
          
            if(@account.save)
              @Transaction = Transaction.new
              @Transaction.transaction_type = withdraw_type
              @Transaction.status = approved_status
              @Transaction.start = Time.now
              @Transaction.finish = Time.now
              @Transaction.amount = withdraw_amount
              @Transaction.account_id = params[:account_id].to_i

              if @Transaction.save
                flash[:success] = "Withdrawal successful"
              else
                flash[:danger] = "Withdrawal was Successful, but failed to record transaction"
              end
          end
        else
          flash[:danger] = "Insufficient funds"
        end
        redirect_to account_url
      end    
    end

    def new_account
      render 'home'
    end

    private
 	  def user_params
  	  params.require(:user).permit(:name, :email,:password,:password_confirmation)
    end
end
end