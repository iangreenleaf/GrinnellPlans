require 'spec_helper'

describe AccountsController do
  after do
    ActionMailer::Base.deliveries.clear
  end

  it "should get registration page" do
    get(:new)
    assert_response(:success)
    assert_select("form", /My Grinnell email is/)
  end

  it "should create tentative account and send email" do
    ta = TentativeAccount.find_by_username("plans")
    assert_nil(ta)
    post(:create, :account => {"username" => "plans", "email_domain" => "blop.blop", "user_type" => "student"})
    assert_select("p", /was just sent to plans@blop.blop/)
    ta = TentativeAccount.find_by_username("plans")
    ta.email.should == "plans@blop.blop"
    email = ActionMailer::Base.deliveries.first
    email.subject.should == "Plan Activation Link"
    email.to[0].should == "plans@blop.blop"
    assert_match("will expire in 24 hours", email.body)
  end

  it "valid tentative account already exists" do
    ta = TentativeAccount.create(:username => "plans", :user_type => "student", :email => "plans@blop.blop", :confirmation_token => "PLAN9")
    post(:create, :account => {:username => ta.username, :email_domain => "blop.blop"})
    assert_select("p", /A confirmation email has already been sent to #{ta.email}/)
  end

  it "account already exists" do
    ta = TentativeAccount.create(:username => "plans", :user_type => "student", :email => "plan@blop.blop")
    account = Account.create_new(ta)
    account.should_not be_nil
    post(:create, :account => {"username" => "plans"})
    assert_select("p", /A plan already exists for this Grinnellian/)
  end

  it "expired tentative is cleared on create" do
    past_time = Time.now - 2.days
    ta = TentativeAccount.create(
      :username => "plans",
      :user_type => "student",
      :email => "plans@blop.blop",
      :confirmation_token => "PLAN9",
      :created_at => past_time,
      :updated_at => past_time
    )
    ta.should_not be_nil
    post(:create, :account => {"username" => "plans", "email_domain" => "blop.blop", "user_type" => "student"})
    assert_select("p", /was just sent to plans@blop.blop/)
    ta = TentativeAccount.find_by_username("plans")
    assert_operator(past_time, :<, ta.created_at)
  end

  it "confirm account successfully" do
    ta = TentativeAccount.create(:username => "plans", :user_type => "student", :email => "plans@blop.blop", :confirmation_token => "PLAN9")
    account = Account.find_by_username(ta.username)
    assert_nil(account)
    get(:confirm, :token => "PLAN9")
    assert_select("p", /Thank you for confirming your email/)
    account = Account.find_by_username("plans")
    account.should_not be_nil
    account.email.should == ta.email
    email = ActionMailer::Base.deliveries.first
    email.subject.should == "Plan Created"
    email.to[0].should == "plans@blop.blop"
    assert_match("Your Plan has been created!", email.body)
    assert_match("Password", email.body)
  end

  it "confirm with expired tentative account" do
    ta = TentativeAccount.create(
      :username => "plans",
      :user_type => "student",
      :email => "plans@blop.blop",
      :confirmation_token => "PLAN9",
      :created_at => Time.now - 2.days,
      :updated_at => Time.now - 2.days
    )
    get(:confirm, :token => "PLAN9")
    assert_redirected_to(:controller => "accounts", :action => "new")
  end

  it "confirm with wrong token" do
    get(:confirm, :token => "SHOO")
    assert_redirected_to(:controller => "accounts", :action => "new")
  end

  it "resend confirmation email" do
    ta = TentativeAccount.create(:username => "plans", :user_type => "student", :email => "plans@blop.blop", :confirmation_token => "PLAN9")
    post(:resend_confirmation_email, :username => "plans")
    email = ActionMailer::Base.deliveries.first
    email.subject.should == "Plan Activation Link"
    email.to[0].should == ta.email
    assert_match("will expire in 24 hours", email.body)
  end
end
