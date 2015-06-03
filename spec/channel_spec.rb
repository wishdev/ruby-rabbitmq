
require 'spec_helper'


describe RabbitMQ::Channel do
  let(:subject_class) { RabbitMQ::Channel }
  let(:connection) { RabbitMQ::Connection.new.start }
  let(:id) { 11 }
  let(:subject) { subject_class.new(connection, id) }
  
  its(:connection) { should eq connection }
  its(:id)         { should eq id }
  
  let(:max_id) { RabbitMQ::FFI::CHANNEL_MAX_ID }
  
  it "cannot be created if the given channel id is already allocated" do
    subject
    expect { subject_class.new(connection, id) }.to \
      raise_error ArgumentError, /already in use/
    expect { subject_class.new(connection, id) }.to \
      raise_error ArgumentError, /already in use/
  end
  
  it "cannot be created if the given channel id is too high" do
    subject_class.new(connection, max_id)
    expect { subject_class.new(connection, max_id + 1) }.to \
      raise_error ArgumentError, /too high/
  end
  
  describe "release" do
    it "releases the channel to be allocated again" do
      subject.release
      subject = subject_class.new(connection, id)
      subject.release
      subject = subject_class.new(connection, id)
    end
    
    it "can be called several times to no additional effect" do
      subject.release
      subject.release
      subject.release
    end
    
    it "returns self" do
      subject.release.should eq subject
    end
  end
  
  it "can perform exchange operations" do
    res = subject.exchange_delete("my_exchange")
    res[:properties].should be_empty
    res = subject.exchange_delete("my_other_exchange")
    res[:properties].should be_empty
    
    res = subject.exchange_declare("my_exchange", "direct", durable: true)
    res[:properties].should be_empty
    res = subject.exchange_declare("my_other_exchange", "topic", durable: true)
    res[:properties].should be_empty
    
    res = subject.exchange_bind("my_exchange", "my_other_exchange", routing_key: "my_key")
    res[:properties].should be_empty
    
    res = subject.exchange_unbind("my_exchange", "my_other_exchange", routing_key: "my_key")
    res[:properties].should be_empty
    
    res = subject.exchange_delete("my_exchange", if_unused: true)
    res[:properties].should be_empty
    res = subject.exchange_delete("my_other_exchange", if_unused: true)
    res[:properties].should be_empty
  end
  
  it "can perform queue operations" do
    subject.exchange_delete("my_exchange")
    subject.exchange_declare("my_exchange", "direct", durable: true)
    
    res = subject.queue_delete("my_queue")
    res[:properties].delete(:message_count).should be_an Integer
    res[:properties].should be_empty
    
    res = subject.queue_declare("my_queue", durable: true)
    res[:properties].delete(:queue)         .should eq "my_queue"
    res[:properties].delete(:message_count) .should be_an Integer
    res[:properties].delete(:consumer_count).should be_an Integer
    res[:properties].should be_empty
    
    res = subject.queue_bind("my_queue", "my_exchange", routing_key: "my_key")
    res[:properties].should be_empty
    res = subject.queue_unbind("my_queue", "my_exchange", routing_key: "my_key")
    res[:properties].should be_empty
    
    res = subject.queue_purge("my_queue")
    res[:properties].delete(:message_count).should be_an Integer
    res[:properties].should be_empty
    
    res = subject.queue_delete("my_queue", if_unused: true)
    res[:properties].delete(:message_count).should be_an Integer
    res[:properties].should be_empty
  end
  
  it "can perform consumer operations" do
    subject.queue_delete("my_queue")
    subject.queue_declare("my_queue")
    
    res = subject.basic_qos(prefetch_count: 10, global: true)
    res[:properties].should be_empty
    
    tag = "my_consumer"
    res = subject.basic_consume("my_queue", tag, exclusive: true)
    res[:properties].delete(:consumer_tag).should eq tag
    res[:properties].should be_empty
    
    res = subject.basic_cancel(tag)
    res[:properties].delete(:consumer_tag).should eq tag
    res[:properties].should be_empty
    
    res = subject.basic_consume("my_queue")
    tag = res[:properties].delete(:consumer_tag)
    tag.should be_a String; tag.should_not be_empty
    res[:properties].should be_empty
    
    res = subject.basic_cancel(tag)
    res[:properties].delete(:consumer_tag).should eq tag
    res[:properties].should be_empty
  end
  
  it "can perform transaction operations" do
    res = subject.tx_select
    res[:properties].should be_empty
    subject.queue_delete("my_queue")
    subject.queue_declare("my_queue")
    res = subject.tx_rollback
    res[:properties].should be_empty
    
    res = subject.tx_select
    res[:properties].should be_empty
    subject.queue_delete("my_queue")
    subject.queue_declare("my_queue")
    res = subject.tx_commit
    res[:properties].should be_empty
  end
  
  it "can perform message operations" do
    subject.queue_delete("my_queue")
    subject.queue_declare("my_queue")
    
    res = subject.basic_publish("message_body", "", "my_queue",
                                persistent: true, priority: 5)
    res.should eq true
    
    res = subject.basic_get("my_queue", no_ack: true)
    res[:properties].delete(:delivery_tag) .should be_an Integer
    res[:properties].delete(:redelivered)  .should eq false
    res[:properties].delete(:exchange)     .should eq ""
    res[:properties].delete(:routing_key)  .should eq "my_queue"
    res[:properties].delete(:message_count).should eq 0
    res[:properties].should be_empty
    res[:header].should be_a Hash
    res[:body].should eq "message_body"
  end
  
end
