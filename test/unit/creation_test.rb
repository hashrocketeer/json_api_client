require 'test_helper'

class CreationTest < MiniTest::Test

  class CallbackTest < TestResource
    include JsonApiClient::Helpers::Callbacks
    before_save do
      self.foo = 10
    end

    after_create :after_create_method

    def after_create_method
      self.bar = 100
    end
  end

  class Author < TestResource
  end

  def setup
    super
    stub_request(:post, "http://example.com/articles")
      .with(headers: {content_type: "application/vnd.api+json", accept: "application/vnd.api+json"}, body: {
        data: {
          type: "articles",
          attributes: {
            title: "Rails is Omakase"
          }
        }
      }.to_json)
      .to_return(headers: {content_type: "application/vnd.api+json"}, body: {
        data: {
          type: "articles",
          id: "1",
          attributes: {
              title: "Rails is Omakase"
          },
          links: {
            self: "http://example.com/articles/1",
            other: {
              href: "http://example.com/other"
            }
          }
        }
      }.to_json)
  end

  def test_can_create_with_class_method
    article = Article.create({
                                 title: "Rails is Omakase"
                             })

    assert article.persisted?, article.inspect
    assert_equal "1", article.id
    assert_equal "Rails is Omakase", article.title
  end

  def test_changed_attributes_empty_after_create_with_class_method
    article = Article.create({
                                 title: "Rails is Omakase"
                             })

    assert_empty article.changed_attributes
  end

  def test_can_create_with_new_record_and_save
    article = Article.new({
                              title: "Rails is Omakase"
                          })

    assert article.save
    assert article.persisted?
    assert_equal "1", article.id
  end

  def test_can_create_with_includes_and_fields
    stub_request(:post, "http://example.com/articles")
        .with(
            headers: { content_type: "application/vnd.api+json", accept: "application/vnd.api+json" },
            query: { include: 'comments,author.comments', fields: { articles: 'title', authors: 'name' } },
            body: {
                data: {
                    type: "articles",
                    attributes: {
                        title: "Rails is Omakase"
                    }
                }
            }.to_json
        ).to_return(
            headers: { content_type: "application/vnd.api+json" },
            body: {
                data: {
                    type: "articles",
                    id: "1",
                    attributes: {
                        title: "Rails is Omakase"
                    },
                    relationships: {
                        comments: {
                            data: [
                                {
                                    id: "2",
                                    type: "comments"
                                }
                            ]
                        },
                        author: {
                            data: nil
                        }
                    }
                },
                included: [
                    {
                        id: "2",
                        type: "comments",
                        attributes: {
                            body: "it is isn't it ?"
                        }
                    }
                ]
            }.to_json
    )
    article = Article.new({
                              title: "Rails is Omakase"
                          })
    article.request_includes(:comments, author: :comments).
        request_select(:title, authors: [:name])

    assert article.save
    assert article.persisted?
    assert_equal "1", article.id
    assert_nil article.author
    assert_equal 1, article.comments.size
    assert_equal "2", article.comments.first.id
    assert_equal "it is isn't it ?", article.comments.first.body
  end

  def test_can_create_with_links
    article = Article.new({
                              title: "Rails is Omakase"
                          })

    assert article.save
    assert article.persisted?
    assert_equal "http://example.com/articles/1", article.links.self
  end

  def test_can_create_with_new_record_with_relationships_and_save
    stub_request(:post, "http://example.com/articles")
      .with(headers: {content_type: "application/vnd.api+json", accept: "application/vnd.api+json"}, body: {
        data: {
          type: "articles",
          attributes: {
            title: "Rails is Omakase"
          }
        }
      }.to_json)
      .to_return(headers: {content_type: "application/vnd.api+json"}, body: {
        data: {
          type: "articles",
          id: "1",
          attributes: {
            title: "Rails is Omakase"
          },
          relationships: {
            comments: {
              data: [
                {
                  id: "1",
                  type: "comments"
                }
              ]
            }
          }
        },
        included: [
          {
            id: "1",
            type: "comments",
            attributes: {
              comments: "it is isn't it ?"
            }
          }
        ]
      }.to_json)

    article = Article.new({title: "Rails is Omakase"})

    assert article.save
    assert article.persisted?
    assert_equal article.comments.length, 1
    assert_equal "1", article.id

  end

  def test_correct_create_with_nil_attribute_value
    stub_request(:post, "http://example.com/authors")
      .with(headers: {
        content_type: "application/vnd.api+json",
        accept: "application/vnd.api+json"
      },
      body: {
        data: {
          type: "authors",
          attributes: {
            name: "John Doe",
            description: nil
          }
        }
      }.to_json)
      .to_return(headers: {
        content_type: "application/vnd.api+json"
      },
      body: {
        data: {
        type: "authors",
        id: "1",
        attributes: {
         name: "John Doe",
         description: nil
        }
      }
    }.to_json)

    author = Author.new({
      name: "John Doe",
      description: nil
    })

    assert author.save
  end

  def test_changed_attributes_empty_after_create_with_new_record_and_save
    article = Article.new({title: "Rails is Omakase"})

    article.save
    assert_empty article.changed_attributes
  end

  def test_callbacks_on_update
    stub_request(:post, "http://example.com/callback_tests")
      .with(headers: {
        content_type: "application/vnd.api+json",
        accept: "application/vnd.api+json"
      },
      body: {
        data: {
          type: "callback_tests",
          attributes: {
            foo: 10,
            bar: 1
          }
        }
      }.to_json)
      .to_return(headers: {
        content_type: "application/vnd.api+json"
      },
      body: {
        data: {
          type: "callback_tests",
          id: "1",
          attributes: {
            foo: 10,
            bar: 1
          }
        }
      }.to_json)

    callback_test = CallbackTest.create({foo: 1, bar: 1})
    assert_equal 100, callback_test.bar
  end

  def test_create_with_relationships_in_payload
    stub_request(:post, 'http://example.com/articles')
        .with(headers: {content_type: 'application/vnd.api+json', accept: 'application/vnd.api+json'}, body: {
            data: {
                type: 'articles',
                attributes: {
                    title: 'Rails is Omakase'
                },
                relationships: {
                    comments: {
                        data: [
                            {
                                id: '2',
                                type: 'comments'
                            }
                        ]
                    }
                }
            }
        }.to_json)
        .to_return(headers: {content_type: 'application/vnd.api+json'}, body: {
            data: {
                type: 'articles',
                id: '1',
                attributes: {
                    title: 'Rails is Omakase'
                }
            }
        }.to_json)

    article = Article.new(title: 'Rails is Omakase', relationships: {comments: [Comment.new(id: 2)]})

    assert article.save
    assert article.persisted?
    assert_equal "1", article.id
  end

end
