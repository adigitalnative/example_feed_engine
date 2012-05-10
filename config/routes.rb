FeedEngine::Application.routes.draw do
  resource :dashboard, :controller => 'dashboard'

  resources :text_items
  resources :link_items
  resources :image_items

  devise_for :users 

  devise_scope :user do 
    get "signup" => "devise/registrations#new", :as => :new_user
  end
end

