class CommentsController < ApplicationController

def create
  @article = Article.find(params[:article_id])
  @comment = @article.comments.create!(params[:comment].permit!)
  redirect_to @article, :notice => "Comment created!"
end
end
